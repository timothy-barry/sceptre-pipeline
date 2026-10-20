#!/usr/bin/env python3
"""Summarize measured quantities without extrapolating screen-scale performance."""
import collections,csv,json,math,pathlib,sys
out=pathlib.Path(sys.argv[1]); commands=json.loads((out/'commands.json').read_text())
cmd={row['name']:row for row in commands}; direct=json.loads((out/'direct-resources.json').read_text())
plan=json.loads((out/'direct/realized-plan.json').read_text()); timings=json.loads((out/'direct/timings.json').read_text())
rows=[{'method':'independent-public-R','requested_units':0,'actual_workers':1,
 'observed_max_concurrent_workers':1,'command_wall_seconds':cmd['direct']['wall_seconds'],'R_or_task_wall_seconds':direct['elapsed_seconds'],
 'discovery_R_seconds':timings['discovery']['elapsed_seconds'],'CPU_seconds':int(dict(line.split() for line in direct['cgroup_cpu_stat'])['usage_usec'])/1e6,
 'max_container_peak_bytes':int(direct['cgroup_memory_peak_bytes']),'R_peak_RSS_bytes':direct['process_peak_rss_kib']*1024,
 'exact_agreement':'reference','task_count':1}]
for directory in sorted(out.glob('pipeline-units-*')):
    n=int(directory.name.rsplit('-',1)[1]); resource=directory/'task-kernel-resources.csv'
    if not resource.exists(): continue
    tasks=list(csv.DictReader(resource.open()))
    workers=[]
    for task in tasks:
        text=(pathlib.Path(task['work_directory'])/'.command.sh').read_text()
        task['phase']=('worker' if 'distributed_stage.R worker ' in text else
            'prepare' if 'distributed_stage.R prepare ' in text else
            'collect' if 'distributed_stage.R collect ' in text else
            'export/report' if 'export_state.R' in text else
            'validate' if 'validate_state.R' in text else 'preparation-stage')
        if task['phase']=='worker': workers.append(task)
    with (directory/'task-kernel-resources.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=list(tasks[0])); w.writeheader(); w.writerows(tasks)
    events=[]
    for t in workers:
        task=pathlib.Path(t['work_directory'])
        events.extend([(float((task/'.benchmark-start').read_text()),1),(float((task/'.benchmark-end').read_text()),-1)])
    active=peak=0
    for _,delta in sorted(events): active+=delta; peak=max(peak,active)
    comparison=json.loads((directory/'comparison.json').read_text())
    rows.append({'method':'actual-Nextflow-distributed','requested_units':n,'actual_workers':len(workers),
     'observed_max_concurrent_workers':peak,'command_wall_seconds':cmd[f'nextflow-units-{n}']['wall_seconds'],
     'R_or_task_wall_seconds':sum(float(t['elapsed_shell_seconds']) for t in tasks),
     'discovery_R_seconds':'NA (separate prepare/workers/collect)',
     'CPU_seconds':sum(float(t['cgroup_cpu_usage_seconds']) for t in tasks),
     'max_container_peak_bytes':max(int(t['kernel_cgroup_memory_peak_bytes']) for t in tasks),
     'R_peak_RSS_bytes':'NA (per-container kernel peak above)',
     'exact_agreement':comparison['status'],'task_count':len(tasks)})
with (out/'summary.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
result_rows=list(csv.DictReader((out/'direct/result.csv').open()))
stages=dict(collections.Counter(row['stage'] for row in result_rows))
eligible=[row for row in result_rows if row['pass_qc']=='TRUE']
finite_p=all(math.isfinite(float(row['p_value'])) and 0<=float(row['p_value'])<=1 for row in eligible)
if not finite_p: raise SystemExit('Eligible result has a non-finite/out-of-range p-value')
summary={'all_eligible_p_values_finite_and_in_unit_interval':finite_p,'actual_result_stage_counts':stages,'scope':json.loads((out/'fixture/dataset.json').read_text())['scope'],
 'n_requested':plan['requested'],'n_eligible':plan['eligible'],'cells':plan['analyzed_cells'],
 'budgets':{k:plan[k] for k in ('B1','B2','B3','total_resamples')},'measurements':rows,
 'interpretation':'One repetition; actual targeted screen only. Sum of task CPU is resource work, not elapsed latency. Maximum individual-container peak is not simultaneous whole-job peak. Pipeline wall includes JVM/orchestration, serialization, all preparation and export/report; direct wall includes public R stages and benchmark snapshot I/O. Cold fit caches/fresh processes; OS/image caches not flushed.'}
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
