ispc -g -O2 "bc7e.ispc" -o "bc7e.obj" --target=avx2 --opt=fast-math --opt=disable-assertions
lib /OUT:bc7e.lib bc7e.obj
del bc7e.obj
PAUSE