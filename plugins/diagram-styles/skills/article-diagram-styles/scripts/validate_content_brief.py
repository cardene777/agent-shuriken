#!/usr/bin/env python3
"""Validate an article-bound, sample-free content brief before rendering."""
from __future__ import annotations
import argparse,json
from pathlib import Path

FIELDS={'schema_version','mode','article_context','reader_question','takeaway','visual_reason','layout_reason','elements','relations','omit','comparison_request','same_content_requested'}
def nonempty(value):
    return isinstance(value,str) and bool(value.strip())
def validate(data, brief_path):
    if not isinstance(data,dict):return ['content brief must be an object']
    errors=[]
    unknown=set(data)-FIELDS
    if unknown:errors.append('content brief contains non-content fields: '+', '.join(sorted(unknown)))
    mode=data.get('mode','article')
    if mode not in ('article','style-comparison'):errors.append('mode must be article or explicitly requested style-comparison')
    if mode=='style-comparison' and (not nonempty(data.get('comparison_request')) or data.get('same_content_requested') is not True):
        errors.append('style-comparison requires comparison_request and same_content_requested=true')
    context=data.get('article_context')
    if not isinstance(context,dict):errors.append('article_context is required')
    else:
        for key in ('path','heading','excerpt'):
            if not nonempty(context.get(key)):errors.append('article_context.'+key+' is required')
        if nonempty(context.get('path')) and nonempty(context.get('excerpt')):
            p=Path(context['path']).expanduser();p=p if p.is_absolute() else brief_path.parent/p
            try:
                if context['excerpt'].replace('\r\n','\n') not in p.read_text(encoding='utf-8').replace('\r\n','\n'):
                    errors.append('article excerpt does not occur in the current article file')
            except (OSError,UnicodeError):errors.append('article_context.path must be a readable article or draft')
    for key in ('reader_question','takeaway','visual_reason','layout_reason'):
        if not nonempty(data.get(key)):errors.append(key+' is required')
    elements=data.get('elements');ids=[]
    if not isinstance(elements,list) or not elements:errors.append('elements must be a non-empty list')
    else:
        for i,item in enumerate(elements,1):
            if not isinstance(item,dict):errors.append(f'element {i} must be an object');continue
            for key in ('id','meaning','form','why'):
                if not nonempty(item.get(key)):errors.append(f'element {i}: {key} is required')
            if nonempty(item.get('id')):ids.append(item['id'])
            if item.get('basis') not in ('article','visual-convention'):errors.append(f'element {i}: basis must be article or visual-convention, never a style sample')
        if len(ids)!=len(set(ids)):errors.append('element IDs must be unique')
    relations=data.get('relations')
    if not isinstance(relations,list) or not relations:errors.append('relations must be a non-empty list')
    else:
        for i,item in enumerate(relations,1):
            if not isinstance(item,dict):errors.append(f'relation {i} must be an object');continue
            for key in ('meaning','encoding'):
                if not nonempty(item.get(key)):errors.append(f'relation {i}: {key} is required')
            for key in ('from','to'):
                if item.get(key) not in ids:errors.append(f'relation {i}: {key} must refer to an element ID')
    omit=data.get('omit',[])
    if not isinstance(omit,list) or not all(nonempty(value) for value in omit):errors.append('omit must be a string list')
    return errors

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('brief',type=Path);args=parser.parse_args()
    try:errors=validate(json.loads(args.brief.read_text()),args.brief.resolve())
    except (OSError,ValueError) as exc:errors=[str(exc)]
    if errors:
        print('\n'.join('error: '+e for e in errors));return 1
    print('article content brief valid (structure and article binding only)');return 0
if __name__=='__main__':raise SystemExit(main())
