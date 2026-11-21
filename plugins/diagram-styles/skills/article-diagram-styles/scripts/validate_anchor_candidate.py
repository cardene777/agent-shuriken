#!/usr/bin/env python3
"""Validate article-bound review evidence; this does not judge visual usefulness."""
from __future__ import annotations
import argparse,hashlib,json,struct
from pathlib import Path
from diagram_sample_catalog import selection_errors,profile_errors
from validate_content_brief import validate as validate_brief
from validate_figure_spec import validate as validate_spec,source_label_errors

REQUIRED_CHECKS={'article_context_fit','reader_question_answered','semantic_relations_visible','no_unjustified_visuals','readable_at_published_width','exact_content_verified','style_spec_applied'}
def sha256(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def nonempty(value):return isinstance(value,str) and bool(value.strip())
def resolve(base,value):
    p=Path(value).expanduser();return p if p.is_absolute() else (base/p).resolve()
def png_size(path):
    header=path.read_bytes()[:24]
    if len(header)!=24 or header[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('not a PNG: '+str(path))
    return struct.unpack('>II',header[16:24])
def validate(data,review_path,styles=None):
    if not isinstance(data,dict):return ['review must be an object']
    errors=[];base=review_path.parent
    if data.get('schema_version')!=2:errors.append('schema_version must be 2; legacy sample-match reviews cannot approve new article figures')
    if data.get('status')!='candidate-reviewed':errors.append('status must be candidate-reviewed')
    errors.extend(profile_errors(data.get('fixed_style'),data.get('finish_profile'),styles=styles))
    files=data.get('files');resolved={}
    if not isinstance(files,dict):files={};errors.append('files must be an object')
    required={'candidate','preview_528','content_brief','figure_spec'}
    if 'generation_prompt' in files:required.add('generation_prompt')
    for key in required|({'style_reference'} if 'style_reference' in files else set()):
        entry=files.get(key)
        if not isinstance(entry,dict) or not nonempty(entry.get('path')) or not nonempty(entry.get('sha256')):
            errors.append('files.'+key+' requires path and sha256');continue
        p=resolve(base,entry['path'])
        if not p.is_file():errors.append('missing files.'+key+': '+str(p));continue
        if sha256(p)!=entry['sha256']:errors.append('sha256 mismatch for files.'+key)
        resolved[key]=p
    if 'style_reference' in resolved:
        errors.extend(selection_errors(data.get('fixed_style'),str(resolved['style_reference']),data.get('finish_profile'),styles=styles))
    width=data.get('published_width_px',528)
    if not isinstance(width,int) or isinstance(width,bool) or width<=0:errors.append('published_width_px must be a positive integer')
    for key in ('candidate','preview_528'):
        if key in resolved:
            try:
                w,h=png_size(resolved[key])
                if w<1 or h<1:errors.append(key+' must have nonzero dimensions')
                if key=='preview_528' and w!=width:errors.append('preview_528 must match published_width_px')
            except (OSError,ValueError) as exc:errors.append(str(exc))
    brief=None;spec=None
    for key in ('content_brief','figure_spec'):
        if key in resolved:
            try:
                value=json.loads(resolved[key].read_text())
                if key=='content_brief':brief=value;errors.extend(validate_brief(brief,resolved[key]))
                else:spec=value;errors.extend(validate_spec(spec,resolved[key]));errors.extend(source_label_errors(spec,resolved[key]))
            except (OSError,ValueError) as exc:errors.append(key+': '+str(exc))
    if isinstance(brief,dict) and isinstance(spec,dict):
        if spec.get('content_brief_sha256')!=sha256(resolved['content_brief']):errors.append('figure spec must bind the current content brief SHA-256')
        if spec.get('purpose')!=brief.get('takeaway'):errors.append('figure purpose must equal the content brief takeaway')
        for key in ('fixed_style','finish_profile'):
            if spec.get(key)!=data.get(key):errors.append('figure spec '+key+' must match the reviewed style specification')
    checks=data.get('checks');evidence=data.get('evidence')
    if not isinstance(checks,dict):checks={}
    if not isinstance(evidence,dict):evidence={}
    if isinstance(spec,dict) and spec.get('rendering_mode')=='deterministic':
        checks=dict(checks);evidence=dict(evidence)
        if 'exact_content_verified' not in checks:
            checks['exact_content_verified']=checks.get('exact_content_kept_deterministic')
            evidence['exact_content_verified']=evidence.get('exact_content_kept_deterministic')
    if isinstance(spec,dict) and spec.get('rendering_mode')=='generated':
        source=spec.get('source_file');prompt=spec.get('generation_prompt_file')
        if isinstance(source,str) and resolve(resolved['figure_spec'].parent,source)!=resolved.get('candidate'):
            errors.append('generated source_file must be the reviewed candidate')
        if 'generation_prompt' not in resolved:
            errors.append('files.generation_prompt requires the executed prompt path and hash')
        elif isinstance(prompt,str) and resolve(resolved['figure_spec'].parent,prompt)!=resolved['generation_prompt']:
            errors.append('generation_prompt_file must match the reviewed prompt')
        source_checks=data.get('source_checks',[])
        verified_sources={(v.get('source'),v.get('locator')) for v in source_checks if isinstance(v,dict) and nonempty(v.get('evidence'))}
        expected_sources={(v.get('source'),v.get('locator')) for v in [*spec.get('facts',[]),*spec.get('relations',[])] if isinstance(v,dict)}
        if verified_sources!=expected_sources:errors.append('source_checks must record primary-source observations for every source and locator')
        facts=data.get('verified_facts',[]);relations=data.get('verified_relations',[])
        observed={(v.get('text'),v.get('source'),v.get('locator')) for v in facts if isinstance(v,dict) and nonempty(v.get('evidence'))}
        expected={(v.get('text'),v.get('source'),v.get('locator')) for v in spec.get('facts',[]) if isinstance(v,dict)}
        if observed!=expected:errors.append('verified_facts must cover every current image fact with visual evidence')
        observed_rel={(v.get('from'),v.get('to'),v.get('kind'),v.get('source'),v.get('locator')) for v in relations if isinstance(v,dict) and nonempty(v.get('evidence'))}
        expected_rel={(v.get('from'),v.get('to'),v.get('kind'),v.get('source'),v.get('locator')) for v in spec.get('relations',[]) if isinstance(v,dict)}
        if observed_rel!=expected_rel:errors.append('verified_relations must cover every current image relation with visual evidence')
    for name in sorted(REQUIRED_CHECKS):
        if checks.get(name) is not True:errors.append('checks.'+name+' must be true')
        if not nonempty(evidence.get(name)):errors.append('evidence.'+name+' is required')
    review=data.get('review')
    if not isinstance(review,dict):review={}
    if review.get('write_access') is not False:errors.append('review.write_access must be false')
    if review.get('verdict')!='pass':errors.append('review.verdict must be pass')
    if not nonempty(review.get('evaluator')):errors.append('review.evaluator is required')
    if not nonempty(review.get('reader_answer')):errors.append('review.reader_answer must answer the article-specific question')
    if review.get('findings') not in ([],None):errors.append('review.findings must be empty for a passing candidate')
    return errors

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--review',required=True,type=Path)
    parser.add_argument('--styles',help='the styles folder to read instead of ~/.styles');args=parser.parse_args()
    try:errors=validate(json.loads(args.review.read_text()),args.review.resolve(),args.styles)
    except (OSError,ValueError) as exc:errors=[str(exc)]
    if errors:print('\n'.join('error: '+e for e in errors));return 1
    print('article figure review evidence valid; semantic usefulness requires the recorded independent review');return 0
if __name__=='__main__':raise SystemExit(main())
