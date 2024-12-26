#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

# TrueOG Bootstrap Stage 1: Bootstrap pkgsrc from bash and C.

# Detect what enviornment the script is being run on and store it in variables for later reference.
ARCHITECTURE=$(uname -m)
OS=$(uname -s)

# Store bootstrap root directory as enviornment variable for later reference
BOOTROOT=$PWD

# Introduce the functionality of the bootstrap to user.
echo -e "\nWelcome to the TrueOG Server Bootstrap. This script will enable you to build a 100% Open Source Minecraft server based on https://true-og.net's code base.\n\nThis is public domain software created with love by NotAlexNoyle and the TrueOG community. It's free: as in freedom! The way the Minecraft ecosystem should be."
echo -e "\nYour platform: $OS-$ARCHITECTURE is supported!\n"
# Require user input to begin the process.
read -p $'You will be asked for information to help set up the build enviornment.\nAfter that, the automated bootstrap will take 1-2 hours to build your Minecraft server from source.\n\nAre you ready to begin? [Enter]'

# Linux platform compatibility
linuxPrompts() {

	# Scan for NixOS and store result in variable.
	NIXORNOT=$(uname -v)
	# Handle NixOS prerequisite edge case.
	if [[ "$NIXORNOT" == *"NixOS"* ]]; then
		# Inform user about how packages will interface with their operating system and prompt for confirmation.
		read -p $'\nPlease note that if you run the Nix garbage collector and it collects libc, every pkgsrc binary (including binaries generated during it''s bootstrap) will need to be rebuilt! [Enter]' && echo
	fi

	# TODO: Evaluate JDKs for platform compatibility so you know what if statements to write.
	# Provide a brief description of Adoptium to user.
	echo -e "\nadoptium - Eclipse runtime, well supported and TCK certified."
	# If architecture is amd64/x86_64 or ARM (the Linux architectures supported by GraalVM), do this.
	if [[ $ARCHITECTURE == *"x86_64"* || $ARCHITECTURE == *"amd64"* || $ARCHITECTURE == *"arm"* || $ARCHITECTURE == *"ARM"* ]]; then
		# If bitness is 64 bit, do this.
		BITNESS=$(getconf LONG_BIT)
		if [[ $BITNESS == 64 ]]; then
			# If system is not musl, do this.
			MUSLORNOT=$(grep "" /lib/ld-* -l)
			if ! [[ $MUSLORNOT == *"musl"* ]]; then
				# Provide a brief description of GraalVM to the user.
				echo "graalvm - Optimized, polyglot, the engine powering TrueOG since it's inception."
			fi
		fi
	else
		echo -e "\nUnsupported Architecture: $ARCHITECTURE" && exit 0
	fi

	echo "microsoft - A fork of adoptium by the company that owns Minecraft."
	echo "pkgsrc - pkgsrc's implementation of the OpenJDK 17 LTS."
	echo -e "manual - specify your own absolute path to the JAVA_HOME you want to use.\n"

	# TODO: Loop the below options menu into platform specific JDK exclusions.
	# Ask the user what JDK they want to use.
	read -p $'Which OpenJDK 17 distribution would you like to use? [adoptium, graalvm, microsoft, pkgsrc]: ' CHOSENJDK

}

# TODO: Add more platforms from spreadsheet
# Detect the operating system to dynamically change prompts.
case $OS in
	# TODO: Make more details in prompts
	Linux ) linuxPrompts;;
	Darwin ) macPrompts;;
	CYGWIN ) windowsPrompts;;
	FreeBSD ) freeBsdFamilyPrompts;;
	DragonFly ) freeBsdFamilyPrompts;;
	MidnightBSD ) freeBsdFamilyPrompts;;
	# Bail out of the script if it's being run on an unsupported platform.
	*) echo -e "\nHALTED: Unsupported Platform: $OS-$ARCHITECTURE" && exit 0;;
esac

# If git is found, do this.
if [[ -x "$(command -v git)" ]]; then
	# Store email with prefix in variable to evaluate whether it has been set.
	GITEMAIL=$(git config user.email)
	# If git email is null, do this.
	if [[ ! "$GITEMAIL" ]]; then
		# Store git email in enviornment as a variable for evaluation.
		read -p $'\nEnter your email address for use with git: ' NEWEMAIL
		# Set git email for local session based on user input.
		git config --global user.email "$NEWEMAIL"
	# If git email is not null, do this.
	else
		# Informs user about the git email in use.
		echo -e "\ngit email address already configured: $GITEMAIL"
	fi

	# Store username with prefix in variable to evaluate whether it has been set.
	GITUSERNAME=$(git config user.name)
	# If git username is null, do this.
	if [[ ! "$GITUSERNAME" ]]; then
		# Store git username in enviornment as a variable for evaluation.
		read -p $'\nEnter your username for use with git: ' NEWUSERNAME && echo
		# Set git username for local session based on user input.
		git config --global user.name "$NEWUSERNAME"
	# If git username is not null, do this.
	else
		# Informs user about the git username in use.
		echo -e "\ngit username already configured: $GITUSERNAME"
	fi
# If git is not found, do this.
else
	# Store git email in enviornment as a variable for later reference.
	read -p $'\nEnter your email address for use with git: ' GITEMAIL
	# Store git username in enviornment as a variable for evaluation.
	read -p $'\nEnter your username for use with git: ' GITUSERNAME
fi

# Install make 4.3 from The GNU Project's FTP server.
makeInstall() {

	# Inform user about download delay.
    echo "Downloading self-contained make from The GNU Project's FTP server..."
 	
	# Download make 4.3 from The GNU Project's FTP server using pure bash and sed (derivative of wget bootstrap hack by warg and Nathan Phillip Brink).
	MAKE_HOSTNAME='ftp.gnu.org'
    exec {HTTP_FD}<>/dev/tcp/${MAKE_HOSTNAME}/80
    echo -ne 'GET /gnu/make/make-4.3.tar.gz HTTP/1.1\r\nHost: '${MAKE_HOSTNAME}'\r\nUser-Agent: bash/'${BASH_VERSION}'\r\n\r\n' >&${HTTP_FD}
    sed -e '1,/^.$/d' <&${HTTP_FD} > make-4.3.tar.gz

    # Inform user about extract delay.
    echo -e "\nExtracting self-contained make...\n"

    # Create directories for make extraction.
    mkdir -p make-latest/make-build/

    # Extract make tarball.
    tar -xf make-4.3.tar.gz --strip-components=1 -C make-latest/

    # Change directory to self-contained make source.
    cd make-latest/

    # Prepare enviornment to build make from source.
    ./configure --disable-dependency-tracking

    # Inform user about potential privilege escalation.
    echo -e "\nEscalating privileges for make build script to be made executable...\n"

    # Make build script executable.
    sudo chmod +x build.sh

    # Build make to be contained inside its own source directory.
    ./build.sh --prefix=$PWD/make-build/

    # Prepare enviornment for make to bootstrap itself
    ./configure --disable-dependency-tracking --prefix=$PWD/make-build/

    # make eating its own dog food.
    ./make

    # make installing itself.
    ./make install

    # Return to the temporary TrueOG dependencies directory.
    cd -

    # Add make to the front of the local PATH.
    export PATH="$PWD/make-latest/make-build/bin/:$PATH"

    # Clean up make tarball.
    rm make-4.3.tar.gz

	# Keep the user up to date with what is happening with make.
	echo -e "\nMake bootstrap subtask complete. Returning to directory:"

}

# Install the latest available m4 from The GNU Project's FTP server.
# This will only be invoked if GNUTLS gets bootstrapped.
m4Install() {

	# Inform user about download delay.
	echo "Downloading self-contained m4 from The GNU Project's FTP server..."
 		
	# Download the latest available version of m4 from The GNU Project's FTP server using pure bash and sed (derivative of wget bootstrap hack by warg and Nathan Phillip Brink).
	M4_HOSTNAME='ftp.gnu.org'
    exec {HTTP_FD}<>/dev/tcp/${M4_HOSTNAME}/80
    echo -ne 'GET /gnu/m4/m4-latest.tar.gz HTTP/1.1\r\nHost: '${M4_HOSTNAME}'\r\nUser-Agent: bash/'${BASH_VERSION}'\r\n\r\n' >&${HTTP_FD}
    sed -e '1,/^.$/d' <&${HTTP_FD} > m4-latest.tar.gz

	# Inform user about extract delay.
	echo -e "\nExtracting self-contained m4...\n"

	# Create directories for m4 extraction.
	mkdir -p m4-latest/m4-build/

	# Extract m4 tarball.
	tar -xf m4-latest.tar.gz --strip-components=1 -C m4-latest/

	# Change directory to self-contained m4 source.
	cd m4-latest/

	# Inform user about potential privilege escalation.
	echo -e "Escalating privileges for m4 configure script to be made executable...\n"
	
	# Make configure script executable.
	sudo chmod +x configure
	
	# Prepare enviornment to build m4 from source.
	./configure --prefix=$PWD/m4-build/

	# Build m4 from source.
	make

	# Install m4 in a self-contained directory.
	make install

	# Return to the temporary TrueOG dependencies directory (with spacer).
	cd - && echo

	# Add m4 to the front of the local PATH.
	export PATH="$PWD/m4-latest/m4-build/bin:$PATH"

	# Clean up m4 tarball.
	rm m4-latest.tar.gz

	# Keep the user up to date with what is happening with m4.
	echo -e "\nm4 bootstrap subtask complete. Returning to directory:"

}

# Install GMP 6.2.1 from the GNU Project.
# This will only be invoked if GNUTLS gets bootstrapped.
gmpInstall() {

	# Inform user about download delay.
	echo "Downloading self-contained GMP from The GNU Project's FTP server..."
 		
	# Download GMP 6.2.1 from The GNU Project's FTP server using pure bash and sed (derivative of wget bootstrap hack by warg and Nathan Phillip Brink).
	GMP_HOSTNAME='ftp.gnu.org'
    exec {HTTP_FD}<>/dev/tcp/${GMP_HOSTNAME}/80
    echo -ne 'GET /gnu/gmp/gmp-6.2.1.tar.xz HTTP/1.1\r\nHost: '${GMP_HOSTNAME}'\r\nUser-Agent: bash/'${BASH_VERSION}'\r\n\r\n' >&${HTTP_FD}
    sed -e '1,/^.$/d' <&${HTTP_FD} > gmp-6.2.1.tar.xz

	# Inform user about extract delay.
	echo -e "\nExtracting self-contained GMP...\n"

	# Create directories for GMP extraction.
	mkdir -p gmp-6.2.1/gmp-build/

	# Extract GMP tarball.
	tar -xf gmp-6.2.1.tar.xz --strip-components=1 -C gmp-6.2.1/

	# Change directory to self-contained GMP source.
	cd gmp-6.2.1/

	# Inform user about potential privilege escalation.
	echo -e "Escalating privileges for GMP configure script to be made executable...\n"
	
	# Make configure script executable.
	sudo chmod +x configure
	
	# Prepare enviornment to build GMP from source.
	./configure --prefix=$PWD/gmp-build/

	# Build GMP from source.
	make

	# Install GMP in a self-contained directory.
	make install

	# Store GMP directory as enviornment variable for library linking.
	GMPDIR=$PWD

	# Return to the temporary TrueOG dependencies directory.
	cd -

	# Force GMP shared binary object files into library PATH so that it can always be seen by nettle's configure script.
	export LD_LIBRARY_PATH="$PWD/gmp-6.2.1/gmp-build/lib/"
	export PKG_CONFIG_PATH="$PWD/gmp-6.2.1/gmp-build/lib/pkgconfig/"

	# Add GMP to the front of the local PATH.
	export PATH="$PWD/gmp-6.2.1/gmp-build/lib/:$PATH"

	# Clean up GMP tarball.
	rm gmp-6.2.1.tar.xz

	# Keep the user up to date with what is happening with GMP.
	echo -e "\nGMP bootstrap subtask complete. Returning to directory:"

}

# Install nettle 3.6 from The GNU Project's FTP server.
# This will only be invoked if GNUTLS gets bootstrapped.
nettleInstall() {

	# Inform user about download delay.
    echo "Downloading self-contained nettle from The GNU Project's FTP server..."

	# Download nettle 3.6 from The GNU Project's FTP server using pure bash and sed (derivative of wget bootstrap hack by warg and Nathan Phillip Brink).
    NETTLE_HOSTNAME='ftp.gnu.org'
    exec {HTTP_FD}<>/dev/tcp/${NETTLE_HOSTNAME}/80
    echo -ne 'GET /gnu/nettle/nettle-3.6.tar.gz HTTP/1.1\r\nHost: '${NETTLE_HOSTNAME}'\r\nUser-Agent: bash/'${BASH_VERSION}'\r\n\r\n' >&${HTTP_FD}
    sed -e '1,/^.$/d' <&${HTTP_FD} > nettle-3.6.tar.gz

    # Inform user about extract delay.
    echo -e "\nExtracting self-contained nettle...\n"

    # Create directory for nettle extraction.
    mkdir -p nettle-3.6

    # Extract nettle tarball.
    tar -xf nettle-3.6.tar.gz --strip-components=1 -C nettle-3.6/

	# Install nettle dependency 'm4' first or else the build will fail.
	m4Install

	# Install nettle dependency 'gmp' first or else GNUTLS will not be able to find nettle.
	gmpInstall

	# Change directory to self-contained nettle source.
	cd nettle-3.6/

    # Inform user about potential privilege escalation.
    echo -e "Escalating privileges for nettle configure script to be made executable...\n"
	
	# Make configure script executable.
	sudo chmod +x configure

    # Prepare enviornment to build nettle from source.
	./configure --disable-openssl --enable-shared --enable-mini-gmp --prefix=$PWD/

	# Build nettle from source with GMP libraries linked manually.
	LDFLAGS="-L$GMPDIR/gmp-build/lib/" CPPFLAGS="-I$GMPDIR/gmp-build/include/" make

	# Install nettle in a self-contained directory.
	make install

	# Store nettle directory as enviornment variable for library linking.
	NETTLEDIR=$PWD

	# Return to the temporary TrueOG dependencies directory (with spacer).
	cd - && echo

	# Force libnettle shared binary object files into library PATH so that it can always be seen by GNUTLS's configure script.
	export LD_LIBRARY_PATH="$PWD/nettle-3.6/lib/:$LD_LIBRARY_PATH"
	export PKG_CONFIG_PATH="$PWD/nettle-3.6/lib/pkgconfig/:$PKG_CONFIG_PATH"

	# Add nettle to the front of the local PATH.
	# Two paths are specified to help pressure nettle into linking with compile scripts.
	export PATH="$PWD/nettle-3.6/:$PATH"
	export PATH="$PWD/nettle-3.6/bin/:$PATH"

	# Clean up nettle tarball.
	rm nettle-3.6.tar.gz

	# Keep the user up to date with what is happening with nettle.
	echo -e "\nnettle bootstrap subtask complete. Returning to directory:"

}

# Install libtool 2.4.7 from The GNU Project's FTP server.
# This will only be invoked if GNUTLS gets bootstrapped.
libtoolInstall() {

	# Inform user about download delay.
	echo "Downloading self-contained libtool from The GNU Project's FTP server..."
 		
	# Download libtool 2.4.7 from The GNU Project's FTP server using pure bash and sed (derivative of wget bootstrap hack by warg and Nathan Phillip Brink).
	LIBTOOL_HOSTNAME='ftp.gnu.org'
    exec {HTTP_FD}<>/dev/tcp/${LIBTOOL_HOSTNAME}/80
    echo -ne 'GET /gnu/libtool/libtool-2.4.7.tar.xz HTTP/1.1\r\nHost: '${LIBTOOL_HOSTNAME}'\r\nUser-Agent: bash/'${BASH_VERSION}'\r\n\r\n' >&${HTTP_FD}
    sed -e '1,/^.$/d' <&${HTTP_FD} > libtool-2.4.7.tar.xz

	# Inform user about extract delay.
	echo -e "\nExtracting self-contained libtool...\n"

	# Create directories for libtool extraction.
	mkdir -p libtool-2.4.7/libtool-build/

	# Extract libtool tarball.
	tar -xf libtool-2.4.7.tar.xz --strip-components=1 -C libtool-2.4.7/

	# Change directory to self-contained libtool source.
	cd libtool-2.4.7/

	# Inform user about potential privilege escalation.
	echo -e "Escalating privileges for libtool configure script to be made executable...\n"
	
	# Make configure script executable.
	sudo chmod +x configure
	
	# Prepare enviornment to build GMP from source.
	./configure --prefix=$PWD/libtool-build/

	# Build libtool from source.
	make

	# Install libtool in a self-contained directory.
	make install

	# Return to the temporary TrueOG dependencies directory (with spacer).
	cd - && echo

	# Add libtool to the front of the local PATH.
	export PATH="$PWD/libtool-2.4.7/libtool-build/bin/:$PATH"

	# Clean up GMP tarball.
	rm libtool-2.4.7.tar.xz

	# Keep the user up to date with what is happening with libtool.
	echo -e "\nlibtool bootstrap subtask complete. Returning to directory:"

}

# Install GNUTLS 3.7.8 by the GNU Project from Ireland's National Education & Research Network's FTP server.
gnuTLSInstall() {

	# Inform user about download delay.
	echo -e "\nDownloading self-contained GNUTLS by the GNU Project from Ireland's National Education & Research Network's FTP server (fastest mirror)..."

	# Download GNUTLS 3.7.8 by the GNU Project from Ireland's National Education & Research Network's FTP server using pure bash and sed (derivative of wget bootstrap hack by warg and Nathan Phillip Brink).
    GNUTLS_HOSTNAME='ftp.heanet.ie'
    exec {HTTP_FD}<>/dev/tcp/${GNUTLS_HOSTNAME}/80
    echo -ne 'GET /mirrors/ftp.gnupg.org/gcrypt/gnutls/v3.7/gnutls-3.7.8.tar.xz HTTP/1.1\r\nHost: '${GNUTLS_HOSTNAME}'\r\nUser-Agent: bash/'${BASH_VERSION}'\r\n\r\n' >&${HTTP_FD}
    sed -e '1,/^.$/d' <&${HTTP_FD} > gnutls-3.7.8.tar.xz

    # Inform user about extract delay.
    echo -e "\nExtracting self-contained GNUTLS...\n"

    # Create directories for GNUTLS extraction.
    mkdir -p gnutls-3.7.8/gnutls-build/

    # Extract GNUTLS tarball.
    tar -xf gnutls-3.7.8.tar.xz --strip-components=1 -C gnutls-3.7.8/

	# Install GNUTLS dependency 'nettle' first or else the build will fail.
	nettleInstall

	# Install GNUTLS dependency 'libtool' first or else the install will fail.
	libtoolInstall

	# Change directory to self-contained GNUTLS source.
	cd gnutls-3.7.8/

    # Inform user about potential privilege escalation.
	echo -e "Escalating privileges for GNUTLS configure script to be made executable...\n"
	
	# Make configure script executable.
	sudo chmod +x configure

    # Prepare enviornment to build GNUTLS from source.
	./configure --prefix=$PWD/gnutls-build/ --with-included-unistring --with-included-libtasn1 --with-nettle-mini --disable-libdane --without-p11-kit

	# Build GNUTLS from source.
	LDFLAGS="-L$GMPDIR/gmp-build/lib/ -L$NETTLEDIR/lib/ -L$LIBUNBOUNDDIR/libunbound-build/lib/" CPPFLAGS="-I$GMPDIR/gmp-build/include/ -I$NETTLEDIR/include/ -I$LIBUNBOUNDDIR/libunbound-build/include/" make

	# Install GNUTLS in a self-contained directory.
	make install

	# Store GNUTLS directory as enviornment variable for library linking
	GNUTLSDIR=$PWD

	# Return to the temporary TrueOG dependencies directory.
	cd -

	# Force GNUTLS shared binary object files into library PATH so that it can always be seen by wget's configure script.
	export LD_LIBRARY_PATH="$PWD/gnutls-3.7.8/gnutls-build/lib/:$LD_LIBRARY_PATH"
	export PKG_CONFIG_PATH="$PWD/gnutls-3.7.8/gnutls-build/lib/pkgconfig/:$PKG_CONFIG_PATH"

	# Add GNUTLS to the front of the local PATH.
	export PATH="$PWD/gnutls-3.7.8/gnutls-build/bin/:$PATH"

	# Clean up GNUTLS tarball.
	rm gnutls-3.7.8.tar.xz

	# Keep the user up to date with what is happening with GNUTLS.
	echo -e "\nGNUTLS bootstrap subtask complete. Returning to directory:"

}

# Install wget from The GNU Project's FTP server.
wgetInstall() {

    # Inform user about download delay.
    echo -e "\nDownloading self-contained wget from The GNU Project's FTP server..."

	# Download the latest available version of wget from The GNU Project's FTP server using pure bash and sed (derivative of wget bootstrap hack by warg and Nathan Phillip Brink).
    WGET_HOSTNAME='ftp.gnu.org'
    exec {HTTP_FD}<>/dev/tcp/${WGET_HOSTNAME}/80
    echo -ne 'GET /gnu/wget/wget-latest.tar.gz HTTP/1.1\r\nHost: '${WGET_HOSTNAME}'\r\nUser-Agent: bash/'${BASH_VERSION}'\r\n\r\n' >&${HTTP_FD}
    sed -e '1,/^.$/d' <&${HTTP_FD} > wget-latest.tar.gz

    # Inform user about extract delay.
    echo -e "\nExtracting self-contained wget...\n"

	# Create directories for wget extraction.
	mkdir -p wget-latest/wget-build/

    # Extract wget tarball.
    tar -xf wget-latest.tar.gz --strip-components=1 -C wget-latest/

	# Install self-contained make 4.3 from the same repository as wget to avoid version conflicts.
	makeInstall

	# Install self-contained GNUTLS for wget's https processing.
	gnuTLSInstall

	# Change directory to self-contained wget source.
	cd wget-latest/

    # Inform user about potential privilege escalation.
	echo -e "\nEscalating privileges for wget configure script to be made executable...\n"
	
	# Make wget configure script executable.
	sudo chmod +x configure

    # Prepare enviornment to build wget from source.
    ./configure --prefix=$PWD/wget-build/ --with-ssl=gnutls
	
	# Build wget from source.
	LDFLAGS="-L$GNUTLSDIR/gnutls-build/lib/" CPPFLAGS="-I$GNUTLSDIR/gnutls-build/include/" make

	# Install wget in a self-contained directory.
	make install

	# Return to the temporary TrueOG dependencies directory (with spacer).
	cd - && echo

	# Add wget executable to the front of the local PATH.
	export PATH="$PWD/wget-latest/wget-build/bin:$PATH"

	# Clean up wget tarball.
	rm wget-latest.tar.gz

	# Keep the user up to date with what is going on with wget.
	echo -e "\nwget bootstrap subtask complete. Returning to directory:"

}

# Install gawk (aliased GNU nawk-compatible awk implementation "gawk") from The GNU Project's FTP server.
# This will only be invoked on systems without glibc, which provides nawk.
nawkInstall() {

	# Inform user about download delay.
	echo -e "\nDownloading self-contained gawk from The GNU Project's FTP server..."
 		
	# Download the latest available version of gawk from The GNU Project's FTP server using pure bash and sed (derivative of wget bootstrap hack by warg and Nathan Phillip Brink).
	GAWK_HOSTNAME='ftp.gnu.org'
    exec {HTTP_FD}<>/dev/tcp/${GAWK_HOSTNAME}/80
    echo -ne 'GET /gnu/gawk/gawk-5.2.1.tar.gz HTTP/1.1\r\nHost: '${GAWK_HOSTNAME}'\r\nUser-Agent: bash/'${BASH_VERSION}'\r\n\r\n' >&${HTTP_FD}
    sed -e '1,/^.$/d' <&${HTTP_FD} > gawk-5.2.1.tar.gz

	# Inform user about extract delay.
	echo -e "\nExtracting self-contained gawk...\n"

	# Create directories for gawk extraction.
	mkdir -p gawk-5.2.1/gawk-build/

	# Extract gawk tarball.
	tar -xf gawk-5.2.1.tar.gz --strip-components=1 -C gawk-5.2.1/

	# Change directory to self-contained gawk source.
	cd gawk-5.2.1/

	# Inform user about potential privilege escalation.
	echo -e "Escalating privileges for gawk configure script to be made executable...\n"
	
	# Make configure script executable.
	sudo chmod +x configure
	
	# Prepare enviornment to build gawk from source.
	./configure --prefix=$PWD/gawk-build/ --disable-dependency-tracking

	# Build gawk from source.
	make

	# Install gawk in a self-contained directory.
	make install

	# Add gawk/nawk to PATH
	export PATH="$PWD/gawk-build/bin:$PATH"

	# Return to the temporary TrueOG dependencies directory (with spacer).
	cd - && echo

	# Create directories for communicating with pkgsrc.
	mkdir -p pkgsrc-build/bin/
	
	# Create symbolic link to nawk for pkgsrc.
	ln -sf $PWD/gawk-5.2.1/gawk-build/bin/gawk $PWD/pkgsrc-build/bin/nawk

	# Clean up gawk tarball.
	rm gawk-5.2.1.tar.gz

	# Keep the user up to date with what is happening with gawk.
	echo -e "\ngawk bootstrap subtask complete. Returning to directory:"

}

# Install a self-contained instance of the pkgsrc package manager.
# This will only be invoked if packages required for the TrueOG bootstrap cannot be found.
pkgsrcInstall() {

	# If pkgsrc not found, do this.
	if ! [[ -x "$(command -v pkgin)" ]]; then
		# Scan for NixOS and store result in variable.
		NIXORNOT=$(uname -v)
		# Handle NixOS prerequisite edge case.
		if [[ "$NIXORNOT" == *"NixOS"* ]]; then
			# Install standard enviornment which is required to build packages.
			nix-build '<nixpkgs>' -A stdenv
		fi
		# If apt found, do this.
		if [[ -x "$(command -v apt)" ]]; then
			# Inform user about potential privilege escalation (with spacer).
			echo -e "\nEscalating privileges to install pkgsrc prerequisites using apt..." && echo
			# Handle apt derivitives prerequisite edge case (debian, ubuntu, iOS, etc).
			sudo apt-get install cvs libncurses5 libncurses5-dev gcc g++ zlib1g-dev zlib1g libudev-dev
		fi
		# If apk found, do this.
		if [[ -x "$(command -v apk)" ]]; then
			# Inform user about potential privilege escalation (with spacer).
			echo -e "\nEscalating privileges to install pkgsrc prerequisites using apk..." && echo
			# Handle apk derivitives prerequisite edge case (Alpine Linux, Android, etc).
			sudo apk add procps coreutils
		fi
		# Create temporary directory for bootstrapping dependencies.
		mkdir trueog-dependencies-temp/
		# Change directory to temporary bootstrap dependency directory.
		cd trueog-dependencies-temp/
		# Build and install wget and its dependencies from source.
		wgetInstall
		# Change back to the pkgsrc bootstrap directory.
		cd $BOOTROOT/pkgsrc/
		# Download pkgsrc repository from GitHub with bootstrapped wget.
		wget -O trunk.zip --content-disposition https://github.com/NetBSD/pkgsrc/archive/refs/heads/trunk.zip
		# Unzip pkgsrc source tree.
		unzip -o trunk.zip
		# Clean up pkgsrc source tree zip file.
		rm trunk.zip
		# If system is not running linux's glibc, do this.
		if ! [[ $MUSLORNOT == *"linux"* ]]; then
			# Install nawk.
			nawkInstall
			# Create directory to contain list-dependencies.
			mkdir -p $BOOTROOT/pkgsrc/pkgsrc-trunk/mk/pkgformat/pkg/
			# Manually fetch list-dependencies.
			wget -O $BOOTROOT/pkgsrc/pkgsrc-trunk/mk/pkgformat/pkg/list-dependencies --content-disposition https://raw.githubusercontent.com/NotAlexNoyle/pkgsrc/trunk/mk/pkgformat/pkg/list-dependencies
			# Inform user about potential privilege escalation (with spacer).
			echo -e "\nEscalating privileges to assist pkgsrc bootstrapping on musl..." && echo
			# Make list-dependencies executable.
			sudo chmod +x $BOOTROOT/pkgsrc/pkgsrc-trunk/mk/pkgformat/pkg/list-dependencies
		fi
		# Change the directory to the pkgsrc bootstrap.
		cd pkgsrc-trunk/bootstrap/
		# Inform user about potential privilege escalation.
		echo -e "\nEscalating privileges to make the pkgsrc bootstrap executable...\n"
		# Make pkgsrc bootstrap script executable.
		sudo chmod +x bootstrap
		# Execute pkgsrc bootstrap script with self-contained directories.
		./bootstrap --prefix=$BOOTROOT/pkgsrc/pkgsrc-build --unprivileged
		# Enable pkgsrc's vulnerability scanning
		pkgsrc-build/sbin/pkg_admin -K pkgsrc-build/pkgdb fetch-pkg-vulnerabilities
		# Create file to later detect that pkgsrc was bootstrapped.
		touch pkgsrc-bootstrapped.txt
		# Change directory back to pkgsrc root.
		cd $BOOTROOT/pkgsrc/
		# Clean up after nawk bootstrap.
		# TODO: REMOVE rm -rf gawk-5.2.1/
	fi

}

# Install a self-contained instance of libidn2 via pkgsrc.
# This will only be invoked if git gets bootstrapped.
libidn2Install() {

	# Change directory to libidn2 source code for installation.
	cd pkgsrc-trunk/devel/libidn2/
	# Build libidn2 with built-in bmake.
	bmake
	# Install libidn2 with built-in bmake.
	bmake install
	# Return to pkgsrc root directory post-install.
	cd $BOOTROOT/pkgsrc/

}

# Install a self-contained instance of nghttp2 via pkgsrc.
# This will only be invoked if git gets bootstrapped.
nghttp2Install() {

	# Change directory to nghttp2 source code for installation.
	cd pkgsrc-trunk/www/nghttp2/
	# Build nghttp2 with built-in bmake.
	bmake
	# Install nghttp2 with built-in bmake.
	bmake install
	# Return to pkgsrc root directory post-install.
	cd $BOOTROOT/pkgsrc/

}

# Install a self-contained instance of GNUTLS via pkgsrc for fetching git certificates.
# This will only be invoked if git gets bootstrapped.
gnutlsCLIInstall() {

	# Change directory to GNUTLS source code for installation.
	cd pkgsrc-trunk/security/gnutls/
	# Build GNUTLS with built-in bmake.
	bmake
	# Install GNUTLS with built-in bmake.
	bmake install
	# Return to pkgsrc root directory post-install.
	cd $BOOTROOT/pkgsrc/

}

# Install a self-contained instance of git via pkgsrc.
gitInstall() {

	# If self-contained pkgsrc is not found, do this.
	if ! [[ -f "pkgsrc/pkgsrc-bootstrapped.txt" ]]; then
		# Make directory to contain pkgsrc bootstrap.
		mkdir pkgsrc/
		# Install self-contained pkgsrc.
		pkgsrcInstall
	# If self-contained pkgsrc is found, do this.
	else
		# Change directory to pkgsrc bootstrap container.
		cd pkgsrc/
	fi
	# Add pkgsrc's bundled bmake to PATH.
	PATH="$PWD/pkgsrc-build/bin/:$PATH"

	# Install git dependency libidn2.
	libidn2Install
	# Install git dependency nghttp2.
	nghttp2Install
	# Install gnutls-cli client as a dependency to fetch git certificates and thus add https support to git.
	gnutlsCLIInstall

	# Change directory to git source code for installation.
	cd pkgsrc-trunk/devel/git-base/
	# Build git with built-in bmake.
	bmake
	# Install git with built-in bmake.
	bmake install

}

# Install git via pkgsrc.
gitInstall
# Set git email for local session based on user input.
git config --global user.email "$GITEMAIL"
# Set git username for local session based on user input.
git config --global user.name "$GITUSERNAME"

# Fetch GitHub's https certificate.
gnutls-cli --print-cert www.github.com < /dev/null > www.github.com.certs
# Tell git where GitHub's https certificate is.
git config --global http.sslcainfo $PWD/www.github.com.certs

# Return to bootstrap root directory
cd $BOOTROOT
# Remove temporary dependencies
rm -rf trueog-dependencies-temp

# Clone TrueOG repository with submodules.
git clone --recursive https://github.com/NotAlexNoyle/true-og/ minecraft-server/
# Switch directories into the git repo.
cd minecraft-server/
# Merge pkgsrc directory into one unified Minecraft server directory.
mv $PKGSRC/ $PWD

# TODO: Finish java install functions!
# Install the Adoptium JDK distribution.
# This will only be invoked if the user selects it.
adoptiumInstall() {

	# Confirm the user selection 
	echo -e "\nInstalling Adoptium OpenJDK..."

	# Fetch Adoptium tarball	

}

# Install the GraalVM JDK distribution.
# This will only be invoked if the user selects it.
graalvmInstall() {

    echo -e "\nInstalling GraalVM OpenJDK..."

}

# Install the Microsoft JDK distribution.
# This will only be invoked if the user selects it.
microsoftInstall() {

    echo -e "\nInstalling Microsoft OpenJDK..."

}

# Install the pkgsrc OpenJDK distribution.
# This will only be invoked if the user selects it.
pkgSrcJdkInstall() {

    echo -e "\nInstalling pkgsrc's OpenJDK..."

}

# Install the JDK that the user has already downloaded.
# This will only be invoked if the user selects it.
installOwnJdk() {

	echo -e "\nInstalling user's own JDK..."

}

# Get java enviornment manager from github.
git clone https://github.com/jenv/jenv

# Add java enviornment manager to local PATH.
PATH="$PWD/jenv/bin:$PATH"

# Initialize java enviornment manager.
eval "$(jenv init -)"

# Run the corresponding install function depending on what OpenJDK distribution the user chose.
case $CHOSENJDK in
	adoptium ) adoptiumInstall;;
	graalvm ) graalvmInstall;;
	microsoft ) microsoftInstall;;
	pkgsrc ) pkgSrcJdkInstall;;
	manual ) installOwnJdk;;
	# Bail out of the script if java if not detected, or else the next steps will fail.
	*) echo -e "\nHALTED: A Java Development Kit is required to build a server based on TrueOG." && exit 0;;
esac

# TODO: Uncomment below section after OpenJDK bootstrap is finished.
# Inform user about potential privilege escalation.
# echo -e "\nEscalating privileges to make Purpur's gradle wrapper executable...\n"

# Make purpur's gradle wrapper executable.
# sudo chmod +x Purpur/gradlew

# Prepare purpur for patches using it's included gradle wrapper.
# Purpur/gradlew applyPatches

# Build purpur and it's dependencies.
# Purpur/gradlew build

# Build purpurclip (includes upstream server software into .jar like bukkit, spigot, paper, etc).
# Purpur/gradlew createReobfPaperclipJar

# Copy the correct purpur server jar to server root.
# cp Purpur/Purpur-Server/build/libs/purpur-server-1.19.2-R0.1-SNAPSHOT-reobf.jar .

# TODO: Purpur config comparison next

# Exit message upon bootstrap completion.
echo -e "\nBootstrap Successful. Welcome to your new TrueOG-based Minecraft server! Check out README.md for tips on where to go from here."

# State project philosophy.
echo -e "\n\"The only way to deal with an unfree world is to become so absolutely free that your very existence is an act of rebellion.\" - Albert Camus\n"
