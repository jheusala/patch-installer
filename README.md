patch-installer
===============

`patch-installer` can be used to create standalone patch scripts. 

USAGE
-----

To create a new standalone patch install script:

	./patch-installer.sh --prev=foo-1.0.0 --next=foo-1.0.1 --create=foo-patch-from-1.0.0-to-1.0.1.sh

You can install the patch by running:

	foo-patch-from-1.0.0-to-1.0.1.sh --install=/path/to/foo

..or just verify the compatibility of target files (install does that too!):

	foo-patch-from-1.0.0-to-1.0.1.sh --check=/path/to/foo

..or export the embedded patch file:

	foo-patch-from-1.0.0-to-1.0.1.sh --get-patch
