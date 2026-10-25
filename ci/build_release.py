"""Reproducible release packaging; no developer-uploaded ZIP is needed."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
RUNTIME_HASH='6a0266cb7571aa4d437a32094acd353f020c77dcf7ff5a3305ae45d0609e5c20'
def version():
    label=re.search(r'^config/version="([^"]+)"',Path('project.godot').read_text(encoding='utf8'),re.M)[1]
    assert re.fullmatch(r'\d+\.\d+(?:\.\d+)?(?: [A-Za-z0-9 ]+)?',label)
    return label,'v'+label.split()[0]
def check():
    label,tag=version()
    r=subprocess.run(['gh','release','view',tag,'--repo',os.environ['GITHUB_REPOSITORY']],capture_output=True)
    exists=r.returncode==0
    with open(os.environ['GITHUB_OUTPUT'],'a',encoding='utf8') as f:f.write(f'tag={tag}\nexists={str(exists).lower()}\n')
    print('Already released; bump config/version for a new update.' if exists else 'Building '+label)
def fetch():
    target=Path('.ci');target.mkdir(exist_ok=True)
    url='https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_win64.exe.zip'
    archive=target/'godot.zip';urllib.request.urlretrieve(url,archive)
    assert hashlib.sha256(archive.read_bytes()).hexdigest()=='088da0457e2d1f7f8a45e6d4605a42b756ea33b9ccd75059bdbc01bb31c2b40d'
    with zipfile.ZipFile(archive) as z:z.extractall(target)
    subprocess.run([sys.executable,'ci/fetch_windows_template.py'],check=True)
    profile=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.1.stable';profile.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(target/'windows_release_x86_64.exe',profile/'windows_release_x86_64.exe')
def run():
    exe=str(ROOT/'.ci/Godot_v4.6.1-stable_win64_console.exe')
    def godot(*args):
        r=subprocess.run([exe,'--headless','--audio-driver','Dummy','--path',str(ROOT),*args],capture_output=True,text=True,encoding='utf8',errors='replace')
        print(r.stdout);print(r.stderr)
        if r.returncode or 'SCRIPT ERROR:' in r.stdout+r.stderr:raise RuntimeError('Godot build/test failed')
    godot('--editor','--import','--quit')
    for suite in ['verify','verify_update','verify_big_city','verify_workshop','verify_hyperdrive','verify_streetlife','verify_thrusters','verify_ice_city','verify_walking']:
        godot('--script',f'res://scripts/{suite}.gd')
    Path('build/Game').mkdir(parents=True,exist_ok=True)
    godot('--export-pack','Windows Desktop',str(ROOT/'build/Game/OpenStreets.pck'))
def package():
    label,tag=version();game=Path('build/Game')
    for name in ['GAME-LICENSE.txt','ENGINE-LICENSES.txt']:shutil.copyfile(Path('licenses')/name,game/name)
    files={name:hashlib.sha256((game/name).read_bytes()).hexdigest() for name in ['OpenStreets.pck','GAME-LICENSE.txt','ENGINE-LICENSES.txt']}
    files={'OpenStreets.exe':RUNTIME_HASH,**files}
    archive=Path('build/OpenStreets-update.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        z.writestr('CHECKSUMS.sha256',''.join(f'{value}  Game/{name}\n' for name,value in files.items()))
        z.writestr('update-info.json',json.dumps({'game':'Open Streets','version':label}))
        z.write('INSTALL.txt','READ-ME.txt')
        for name in files:
            if name!='OpenStreets.exe':z.write(game/name,'Game/'+name)
    with zipfile.ZipFile(archive) as z:assert z.testzip() is None
    feed={'game':'Open Streets','version':label,'zip_url':f'https://github.com/{os.environ["GITHUB_REPOSITORY"]}/releases/download/{tag}/OpenStreets-update.zip','sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'size':archive.stat().st_size,'notes':label+' game update'}
    Path('build/latest.json').write_text(json.dumps(feed,indent=2)+'\n',encoding='utf8')
    print('Release assets ready for',tag)
if __name__=='__main__':
    action=sys.argv[1] if len(sys.argv)>1 else 'build'
    if action=='check':check()
    elif action=='fetch':fetch()
    elif action=='package':package()
    else:fetch();run();package()
