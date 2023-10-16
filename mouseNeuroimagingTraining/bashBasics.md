# Basics of command line programming

## The terminal window
- The terminal window is the program that will display the command line and where we will work during much of our programming
- Most programming that starts in the command line is based on the bash, also known as shell, programming language
- These files have the suffix `.sh` and can be run from the command line by using either `./myScript.sh` or `shell myScript.sh`
- All shell scripts should start with the `#!/bin/bash` shebang 
- Most shell scripts are fairly simple, but can become more complicated (and more useful) as we start to incorporate more scripts and programs with advanced features
- These scripts can access any functions available in your `PATH`
    - The `PATH` on a unix machine is a variable where all of your binary directories are referenced after installation
    - To check the current contents of the `PATH` on your machine, type the command `echo $PATH`

# Installing FSL
- As a way of practicing using the command line, we will install FSL using a premade python script which can be downloaded from the following link:
[FSL downloads page](https://fsl.fmrib.ox.ac.uk/fsldownloads_registration)
- After downloading, there should be a file called `fslinstaller.py` inside your `Downloads` folder
- Change to this directory using the `cd` command and run the installer by calling `python` to run the `.py` file
```
cd Downloads
python fslinstaller.py
```
- Once installation completes, try running the following command to check that the installation worked properly:
```
echo $FSLDIR
```
- This should return something like:
```
/usr/local/fsl
```
## Command glossary
- `echo` - print text to screen
- `cd` - 'change directory', if typed without following options, will change to your home folder
- `ls` - 'list', prints the contents of a directory
- `cp` - 'copy', equivalent to copying and pasting file, original stays in place
- `mv` - 'move', equivalent to cutting and pasting file, original is deleted
- `pwd` - 'primary working directory', prints the name of the current working directory
- `~` - symbol for home folder, i.e. `cd ~` will change directory to `/home/HawkID/`
- `grep` - search function
- `cat` - 'con***cat***enate', print contents of file to terminal window
- `head` - read the start of a file and print to screen
- `tail` - read teh end of a file and print to screen