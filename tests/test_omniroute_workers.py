import importlib.util, pathlib, tempfile, threading, time, unittest
spec=importlib.util.spec_from_file_location('workers', str(pathlib.Path(__file__).resolve().parents[1] / 'home/programs/omniroute-workers.py'));w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
w.STATE=pathlib.Path(tempfile.mkdtemp(prefix='worker-test-'))
class Stream:
 def __init__(self, request):
  self.model=w.json.loads(request.data)['model'];self.status=200
 def __enter__(self):
  with guard:
   active[self.model]=active.get(self.model,0)+1
   peak[self.model]=max(peak.get(self.model,0),active[self.model]);seen.append((time.monotonic(),dict(active)))
  return self
 def __exit__(self,*_):
  with guard:active[self.model]-=1
 def __iter__(self):
  time.sleep(.15)
  yield ('data: '+w.json.dumps({'model':self.model,'choices':[{'delta':{'content':'ok'},'finish_reason':None}]})+'\n').encode()
  yield b'data: [DONE]\n'
guard=threading.Lock();active={};peak={};seen=[]
def wait(batch):
 for _ in range(200):
  result=w.get_batch(batch['batch_id'])
  if result['done']:return result
  time.sleep(.01)
 raise AssertionError('workers did not finish')
class Tests(unittest.TestCase):
 def test_concurrent_hosts_and_per_host_caps(self):
  old=w.urllib.request.urlopen;w.urllib.request.urlopen=lambda req,**kw:Stream(req)
  try:
   tasks=[{'id':str(i),'lane':lane,'prompt':'test'} for i,lane in enumerate(['code','code','code','fast','long'])]
   result=wait(w.start_batch(tasks))
   self.assertTrue(all(t['state']=='completed' for t in result['tasks']))
   self.assertEqual(peak['local/5090'],2)
   self.assertEqual(peak['local/4070ti'],1)
   self.assertEqual(peak['local/m5max'],1)
   self.assertTrue(any(sum(v>0 for v in state.values())==3 for _,state in seen))
   self.assertGreaterEqual(result['tasks'][2]['queue_ms'],100)
  finally:w.urllib.request.urlopen=old
 def test_invalid_batch_has_no_side_effects(self):
  before=len(w.BATCHES)
  with self.assertRaises(ValueError):w.start_batch([{'id':'x','lane':'code','prompt':'x'},{'id':'x','lane':'long','prompt':'x'}])
  self.assertEqual(before,len(w.BATCHES))
 def test_incomplete_stream_is_failure(self):
  class Broken(Stream):
   def __iter__(self):yield b'data: {"choices":[]}\n'
  old=w.urllib.request.urlopen;w.urllib.request.urlopen=lambda req,**kw:Broken(req)
  try:
   result=wait(w.start_batch([{'id':'broken','lane':'fast','prompt':'test'}]))
   self.assertEqual(result['tasks'][0]['state'],'failed')
  finally:w.urllib.request.urlopen=old
if __name__=='__main__':unittest.main()
