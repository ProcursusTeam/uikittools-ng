#include <err.h>
#include <libgen.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef NO_NLS
#	include <libintl.h>
#	define _(a) gettext(a)
#	define PACKAGE "uikittools-ng"
#else
#	define _(a) a
#endif

#ifndef LOCALEDIR
#	define LOCALEDIR "/usr/share/locale"
#endif

#include "deviceinfo.h"

static int backwards_compat(const char* progname, int argc,
								   const char** args);
static int command(const char* cmd, int argc, const char** args);

int main(int argc, const char** argv) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	int rc = backwards_compat(basename((char*)argv[0]), argc, argv);
	if (rc != -1) {
		return rc;
	}

	if (argc < 2) {
		fprintf(stderr, _("Usage: %s [cfversion | ecid | locale | serial | uniqueid] [arguments ...]\n"), getprogname());
		return 1;
	}

	return command(argv[1], argc - 1, argv + 1);
}

static int backwards_compat(const char* progname, int argc,
								   const char** argv) {
	if (!strcmp(progname, "cfversion")) {
		return cfversion();
	} else if (!strcmp(progname, "ecidecid")) {
		return ecid(argc, argv);
	} else if (!strcmp(progname, "uiduid")) {
		return uniqueid();
	}

	return -1;
}

static int command(const char* cmd, int argc, const char** argv) {
	if (!strcmp(cmd, "cfversion")) {
		return cfversion();
	} else if (!strcmp(cmd, "ecid")) {
		return ecid(argc, argv);
	} else if (!strcmp(cmd, "locale")) {
		return locale(argc, argv);
	} else if (!strcmp(cmd, "serial")) {
		return serial();
	} else if (!strcmp(cmd, "uniqueid")) {
		return uniqueid();
	}

	fprintf(stderr, _("Usage: %s [cfversion | ecid | locale | serial | uniqueid] [arguments ...]\n"), getprogname());
	return 1;
}
