# Linux Libraries

This directory contains the compiled native libraries for Linux x86_64.

## Files
- `lib/liboffline_first_core.so` - Dynamic library
- `lib/liboffline_first_core.a` - Static library

## Usage
```bash
# Dynamic linking
gcc -L./lib -loffline_first_core your_program.c

# Static linking  
gcc ./lib/liboffline_first_core.a your_program.c
```

## Dependencies
- LMDB library: `sudo apt-get install liblmdb-dev`
