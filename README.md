# fuzz-aqua-2021
Refactor the 2006 Fuzz aqua to run on Monterey

2006 source: https://ftp.cs.wisc.edu/paradyn/fuzz/ 

Run command example
```
./fuzz-aqua -s <seed number> -d <delay between events> <pid> <event count>
```

## Potential TODO items: 
- [x] Clean up Makefile so it can compile
- [x] Replace deprecated functions
- [x] Add check for accessibility permission, if no exit the application before anything else
- [ ] Create a Xcode project for the code
- [ ] Better memory managemebt, use Automatic Reference Counting(ARC) maybe?
