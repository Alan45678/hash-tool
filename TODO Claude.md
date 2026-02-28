

debug le docker 

+ ajouter des tests pour éviter que ça se reproduise 



wsl-acer@pc-acer:/mnt/c/Users/compt/Desktop/hash-tool$ mkdir -p /tmp/test-bases /tmp/test-data
wsl-acer@pc-acer:/mnt/c/Users/compt/Desktop/hash-tool$ echo "test" > /tmp/test-data/f.txt
wsl-acer@pc-acer:/mnt/c/Users/compt/Desktop/hash-tool$ docker run --rm \
  -v /tmp/test-data:/data:ro \
  -v /tmp/test-bases:/bases \
  hash_tool compute /data /bases/test.b3
Base enregistrée : /bases/test.b3 (1 fichiers)
Sidecar : /bases/test.b3.meta.json
wsl-acer@pc-acer:/mnt/c/Users/compt/Desktop/hash-tool$ ls -la /tmp/test-bases/
total 16
drwxr-xr-x  2 wsl-acer wsl-acer 4096 Feb 28 16:59 .
drwxrwxrwt 10 root     root     4096 Feb 28 16:59 ..
-rw-r--r--  1 root     root       78 Feb 28 16:59 test.b3
-rw-r--r--  1 root     root      173 Feb 28 16:59 test.b3.meta.json
wsl-acer@pc-acer:/mnt/c/Users/compt/Desktop/hash-tool$


