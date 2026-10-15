"""Print transport diagnostics without URLs, tokens or user content."""
import subprocess
adb='/Users/fengzijian/Library/Android/sdk/platform-tools/adb'
base=[adb,'-s','b738806e']
pid=subprocess.check_output(base+['shell','pidof','cn.kelance.bojian']).decode().strip().split()[0]
raw=subprocess.check_output(base+['logcat','-d','--pid='+pid,'-s','flutter:I']).decode(errors='replace')
print('Realtime connections:',raw.count('Bojian realtime connected'))
print('Unhandled exceptions:',raw.count('Unhandled Exception'))
print('Transport failures:',raw.count('Bojian realtime transport:'))
