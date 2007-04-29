/*
*
* BEGIN_HEADER - DO NOT EDIT
*
* The contents of this file are subject to the terms
* of the Common Development and Distribution License
* (the "License").  You may not use this file except
* in compliance with the License.
*
* You can obtain a copy of the license at
* https://open-esb.dev.java.net/public/CDDLv1.0.html.
* See the License for the specific language governing
* permissions and limitations under the License.
*
* When distributing Covered Code, include this CDDL
* HEADER in each file and include the License file at
* https://open-esb.dev.java.net/public/CDDLv1.0.html.
* If applicable add the following below this CDDL HEADER,
* with the fields enclosed by brackets "[]" replaced with
* your own identifying information: Portions Copyright
* [year] [name of copyright owner]
*
*
*
* @(#)makemf.c - ver 1.1 - 01/04/2006
*
* Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
*
* END_HEADER - DO NOT EDIT
*
*/

/*
 * makemf - combine a template and a definition file to create a makefile.
 * Copyright (C) 1990 Russ Tremain
 * May be freely distributed with credit to Author.
 */

#include <errno.h>
#include <stdio.h>
#include <ctype.h>

extern char *malloc();
extern void free();

/*switch the order of these if you want debugging: */
#define	DEBUG	1
#undef	DEBUG

#ifdef MPWTOOL
#	define	PATHSEP	":"
#else
#	define	PATHSEP	"/"
#endif

#define	MAXNAMLEN	256
#define	MAX_LINE	1024*16

/********************************** langext.h **********************************/

/* some language extensions, for readability */
typedef int boolean;
#define true 1
#define false 0
#define Private static
#define Export

#define streq(s1,s2)	(strcmp(s1,s2) == 0)
#define		inrange(L,X,U)	((X) >= (L) && (X) <= (U))
#define		between(L,X,U)	((X) > (L) && (X) < (U))

/********************************** makemf.h  **********************************/

#define	MAKEMFSRC	0
#define	MAKEOUT		1
#define	TEMPLATE	2
#define	MAKEMF_LIB	3
#define	TEMPFOLDER	4

/* storage limits for makemf variables: */
#define	MAXVARS		1500
#define	MAXVARNAME	80
#define	FREEVAR	((char *) -1)

/* default value for makemf program source: */
#define SRC_DEFAULT	"make.mmf"

/*
** error messages:
*/
#define USAGE	"Usage:  %s [-help] [-t template_file] [-o outfile] [-f def_file] [defs...]\nNOTE - Looks for templates in $MAKEMF_LIB.\n"
#define ERRMSG1	"%s:  can't open temporary file %s\n"
#define ERRMSG2	"%s:  can't open %s\n"
#define ERRMSG3	"%s:  parse failed\n"
#define ERRMSG4	"%s:  can't open template, %s\n"
#define ERRMSG5	"%s:  can't open output, %s\n"
#define ERRMSG9	"%s:  build failed\n"

extern char *varname[];
extern char *varvalue[];
extern int nvars;

/********************************** tokens.h  **********************************/

/* warning, punc returns char value, therfore unsafe to name
** any token in the ascii range
*/
#define	IDENTIFIER 300
#define	EOL 301
#define	TEXT 302
#define	PUNC 303

/*********************************** util.h  ***********************************/

extern char *basename();	/* Usage:  basename(char *p) */

/********************************* buildmake.c *********************************/


extern FILE *yyin, *yyoutf;
extern int sc;
extern char yytext[];

extern int linecnt;	/* current line number */
extern int charcnt;	/* current character cnt within current line */

/* lexicon defining sets: */
extern char idstart[], idcont[], puncset[], wspace[];

static int tok;

#define	SCAN()	tok=yylex()

boolean
buildmake()
/*
** perform variable substitutions on template Makefile, creating updated
** version
*/
{
	resetparse();	/* reinitialize scanner vars */

	/* initialize scanner, set current scan char (sc): */
	if (!scan())
		return(true);	/* empty file is okay */

	yyout_on();	/* turn on yyout() (output white-space as is) */

	SCAN();		/* get first token */

	while (line())
		;

	yyout_off();	/* turn off yyout() */

	if (tok == EOF)
		return(true);	/* success if we made it to EOF */
	else {
		yywarn("syntax error\n");
		return(false);
	}
}

boolean
line()
/*
**	make_grammar
**		-> line*
**	
**	line
**		-> '<iden>' '=' text EOL	==> if <iden> in table,
**							substitute new value
**		-> text? EOL			==> output as is
**	
**	text	-> '<any_but_EOL>'*
*/
{
	if (tok == IDENTIFIER) {
		int varnum;
		char savtext[MAX_LINE];

		strcpy(savtext,yytext);

		fputs(yytext,yyoutf);		/* output identifier */

		SCAN();
		if (tok == PUNC && yytext[0] == '=') {
			fputs(yytext,yyoutf);	/* output '=' */
			wsp();			/* output space after '=' */
			varnum = lookup(savtext);
			if (varnum >= 0) {
				/* found def, output it: */
				/* TODO:  make long defs look pretty */
				fprintf(yyoutf," %s",varvalue[varnum]);

				/* eat up rest of line in template, but don't
				** output:
				*/
				text();
				SCAN();
				if (tok == EOL) {
					SCAN();
					return(true);
				}
				else
					return(false);
			}

			/* didn't find var, output text: */
			text();
			fputs(yytext,yyoutf);

			SCAN();
			if (tok == EOL) {
				SCAN();
				return(true);
			}
			else
				return(false);
		}

		/* not '=' - recover and eat up rest of line */
		if (tok == EOL) {
			SCAN();
			return(true);
		}
		else
		if (tok == TEXT) {
			fputs(yytext,yyoutf);
			SCAN();
			if (tok == EOL) {
				SCAN();
				return(true);
			}
		}
		else {
			/* output whatever was there, and eat up remainder
			** of line:
			*/
			fputs(yytext,yyoutf);
			text();
			fputs(yytext,yyoutf);
			SCAN();
			if (tok == EOL) {
				SCAN();
				return(true);
			}
		}
	}
	else
	if (tok == EOL) {
		SCAN();
		return(true);
	}
	if (tok == EOF) {
		return(false);
	}
	else {
		fputs(yytext,yyoutf);
		SCAN();
		if (tok == EOL) {
			SCAN();
			return(true);
		}
	}

	return(false);
}

yylex()
/*
**	lexical analysis -
**		return token type, and optional value.
*/
{
	for(;;) {
		if (isiden()) {
#ifdef	DEBUG
			if (debug(31))
		fprintf(stderr,"lex returned (IDENTIFIER>%s<)\n",yytext);
#endif

			return(IDENTIFIER);
		}
		else if (linecomment())
		{
#ifdef	DEBUG
			if (debug(31))
				fprintf(stderr,"lex read a COMMENT\n");
#endif
			/* ignore */
		}
		else if (punc())
		{
#ifdef	DEBUG
			if (debug(31))
		fprintf(stderr,"lex returned (PUNC>%c<)\n",yytext[0]);
#endif
			return(PUNC);
		}
		else if (eol())
		{
#ifdef	DEBUG
			if (debug(31))
				fprintf(stderr,"lex returned (EOL)\n");
#endif

			return(EOL);
		}
		else if (text())
		{
#ifdef	DEBUG
			if (debug(31))
		fprintf(stderr,"lex returned (TEXT>%s<)\n",yytext);
#endif

			return(TEXT);
		}
		else if (sc == EOF)
		{
#ifdef	DEBUG
			if (debug(31))
				fprintf(stderr,"lex returned (EOF)\n");
#endif

			return(EOF);
		}
		else
			yyerror("yylex: input unrecognized.\n");
	}
}

resetparse()
/* reinitialize scanner vars */
{
	resetscan();

	strcpy(idstart,
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@.$(){}");

	strcpy(idcont,
"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_@.$(){}0123456789");

	strcpy(puncset,"=");
	strcpy(wspace," \t");
}


/********************************** cerror.c  **********************************/


extern char tmpfn[];

cerror(f,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9)
/*
** print error message, unlink tmp file, and die
*/
char *f,*a0,*a1,*a2,*a3,*a4,*a5,*a6,*a7,*a8,*a9;
{
	fprintf(stderr,f,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9);
#ifndef	DEBUG
	unlink(tmpfn);
#else
	fprintf(stderr, "parse input saved in %s\n", tmpfn);
#endif
	exit(-1);
}

/********************************** makemf.c  **********************************/

/* 
** make_grammar -> line*
** 
** line  -> '<iden>' '=' text EOL	==> if <iden> in table,
** 						substitute new value
**       -> text EOL			==> output as is
** 
** text	 -> '<any_but_EOL>'*
** 
** NOTES:
** 
** mkmf_grammar -> statement*
** 
** statement    -> '<iden>' '=' text EOL
** 
** text	-> '<any_but_EOL>'*
** 
** NOTES:
** 
** - contiuation lines are allowed by BACKSLASH escaping newline.
** - C-style comments may appear anywhere except in '<text>'.
*/

/* the name of this program, for error messages: */
char arg0[MAXNAMLEN];

/* temporary file name: */
char tmpfn[MAXNAMLEN];
FILE *yyin, *yyoutf;

/* array of makemf variables: */
char *varname[MAXVARS];
char *varvalue[MAXVARS];
int nvars;

dumpvt(vt)
char *vt[];
{
	int ii;

	for (ii=0;ii<5;ii++) {
		printf("vt[%d] = 0x%x '%s'\n", ii, vt[ii], (vt[ii] == FREEVAR) ? "FREEVAR" : vt[ii]);
	}
}

initvar(vt,idx,val)
char *vt[];
int idx;
char *val;
{
	if (vt[idx] != FREEVAR) {
		free(vt[idx]);
	}

	vt[idx] = (char *) malloc(strlen(val)+1);
	strcpy(vt[idx],val);
}

initvars()
/* initialize reserved variables */
{
	char *p, *getenv();
	int ii = 0;

	for (ii=0; ii< MAXVARS; ii++) {
		varname[ii] = FREEVAR;
	}

	nvars = 0;

	initvar(varname,MAKEMFSRC,"MAKEMFSRC");
	initvar(varvalue,MAKEMFSRC,SRC_DEFAULT);
	++nvars;

	initvar(varname,MAKEOUT,"MAKEOUT");
	initvar(varvalue,MAKEOUT,"stdout");
	++nvars;

	initvar(varname,TEMPLATE,"TEMPLATE");
	initvar(varvalue,TEMPLATE,"file.mmf");
	++nvars;

	initvar(varname,TEMPFOLDER,"TEMPFOLDER");
	/* can define an environment var for the tmp directory: */
	if ((p = getenv(varname[TEMPFOLDER])) == NULL) {
#ifdef	MPWTOOL
		/* mpw shell should define {TempFolder} env. var */
		initvar(varvalue,TEMPFOLDER,"");
		fprintf(stderr, "%s:	warning - TEMPFOLDER defaulting to '%s'\n",
			arg0, varvalue[TEMPFOLDER]);
#else
		initvar(varvalue,TEMPFOLDER,"/tmp");
#endif
	}
	else
		initvar(varvalue,TEMPFOLDER,p);

	initvar(varname,MAKEMF_LIB,"MAKEMF_LIB");
	/* can define an environment var for template directory: */
	if ((p = getenv(varname[MAKEMF_LIB])) == NULL) {
#ifdef	MPWTOOL
		initvar(varvalue,MAKEMF_LIB,"");
#else
		initvar(varvalue,MAKEMF_LIB,"/usr/local/lib/makemf");
#endif
		fprintf(stderr, "%s:	warning - MAKEMF_LIB defaulting to '%s'\n",
			arg0, varvalue[MAKEMF_LIB]);
	}
	else
		initvar(varvalue,MAKEMF_LIB,p);
	++nvars;
}

main(argc,argv)
/*
** makemf - generate a Makefile from templates and user supplied
**	specification.
*/
int argc;
char *argv[];
{
	FILE *f=NULL;
	register int argn;
	register char *p;
	char tmp[MAXNAMLEN];
	int argstatments = 0;	/* number of statments on input line */

#ifdef	DEBUG
	pollbug(&argc,argv);	/* set debug switches if "-bug" arg. found */
#endif

	/* save program name: */
	strcpy(arg0,basename(argv[0]));

	/* initialize builtin vars: */
	initvars();

	/* open temporary file, whether we use it or not: */
	sprintf(tmpfn,"%s%s%s%d", varvalue[TEMPFOLDER], PATHSEP, arg0, getpid());
	if ((yyin = fopen((char *) tmpfn,"w")) == NULL) {
		cerror(ERRMSG1, arg0,tmpfn);
	}

	/*
	** parse the argument vector.  flags can be grouped together
	** or spaced out as in usage message.
	*/
	argn = 1;
	while(argn < argc)	/* while more args... */
	{
		p = argv[argn];
		if (*p == '-') {
			++p;	/* skip over hyphen */
			while (*p != '\0')	/* while more flags... */
			{
				switch(*p) {
				case 'f':
					/* next arg is makemf script */
					if (++argn >= argc)
						cerror(USAGE, arg0);
					initvar(varvalue,MAKEMFSRC,argv[argn]);
					break;
				case 'o':
					/* next arg is output makefile */
					if (++argn >= argc)
						cerror(USAGE, arg0);
					initvar(varvalue,MAKEOUT,argv[argn]);
					break;
				case 't':
					/* next arg is makefile template */
					if (++argn >= argc)
						cerror(USAGE, arg0);
					sprintf((char *) (varvalue[TEMPLATE]), "%s",argv[argn]);
					break;
				case 'h':
					/*
					** option to print usage -
					** not an error
					*/
					fprintf(stderr, USAGE, argv[0]);
					unlink(tmpfn);
					exit(0);
					break;
				default:
					cerror(USAGE, arg0);
					break;
				}
				++p;
			}
		}
		else {
			/* if no flag,  accept as makemf statement to
			** be parsed later.  statement must be legal
			** makemf statement, including quotes:
			*/
			fprintf(yyin,"%s\n",argv[argn]);
			++argstatments;
		}
		++argn;
	}

	/* if source file and statements in arg. list, then combine: */
	f = NULL;
	if (streq(varvalue[MAKEMFSRC],"-"))
		f = stdin;
	else
	if ((f = fopen((char *) (varvalue[MAKEMFSRC]),"r")) == NULL) {
		/* if not default makemf prog name... */
		if (!streq(varvalue[MAKEMFSRC], SRC_DEFAULT))
			cerror(ERRMSG2, arg0,varvalue[MAKEMFSRC]);

		/* o'wise, proceed - not an error for default makemf prog
		** to be missing
		*/
	}

	if (f != NULL || argstatments > 0) {	/* if source statements... */
		if (f != NULL) {
			append(yyin,f);
			fclose(f);
			/* close and reopen yyin for reading: */
			if ((yyin = freopen(tmpfn,"r",yyin)) == NULL)
				cerror(ERRMSG2, arg0,tmpfn);
		}
		/* parse makemf program, output saved in var array: */
		if (!parsemakemf())
			cerror(ERRMSG3, arg0);

	}

	fclose(yyin);	/* done with makemf file */

#ifdef	DEBUG
	if (debug(1))
		dumpvars();

	if (debug(2)) {
		char buf[100];

		sprintf(buf,"cat %s",tmpfn);
		system(buf);
	}
#endif

	/* open up input makefile template: */
	sprintf(tmp,"%s%s%s.Makefile",varvalue[MAKEMF_LIB], PATHSEP, varvalue[TEMPLATE]);
	if ((yyin = fopen(tmp,"r")) == NULL) {
		/* if failed with <TEMPLATE>.Makefile, then try just <TEMPLATE> */
		sprintf(tmp,"%s%s%s",varvalue[MAKEMF_LIB], PATHSEP, varvalue[TEMPLATE]);
		if ((yyin = fopen(tmp,"r")) == NULL) {
			/* still no dice... */
			cerror(ERRMSG4, arg0, tmp);
		}
	}

	/* TODO:  implement imbedded comment feature.  This involves
	** parsing input makefile, scarfing up comments of the form:
	**
	**	#1	begin comment 1
	**		...
	**	#1	end comment 1
	**
	** These comments are substituted in the template wherever a line of
	** the form:
	**
	**	#1 (comment 1 goes here)
	**
	** is found.
	**
	** This substitution is only performed only if input makefile is
	** specified.
	*/

	/* open up output makefile: */
	if (streq("stdout",varvalue[MAKEOUT]))
		yyoutf = stdout;
	else
	if ((yyoutf = fopen((char *) (varvalue[MAKEOUT]),"w")) == NULL)
		cerror(ERRMSG5, arg0, varvalue[MAKEOUT]);

	/* now apply variable substitutions to makefile template: */
	if (!buildmake())
		cerror(ERRMSG9, arg0);

	/* clean up and exit: */
	unlink(tmpfn);
	exit(0);
}

#ifdef	DEBUG
dumpvars()
/* dump variable values: */
{
	int i;

	for (i=0; i<nvars; i++) {
		printf("%s	= '%s'\n",varname[i],varvalue[i]);
	}
}
#endif

addvar(name,value)
char *name, *value;
{
	int i;

	i = lookup(name);

	if (i >=0) {
		initvar(varvalue,i,value);
		return(0);	/* success */
	}

	/* otherwise, allocate a new slot: */
	if (nvars >= MAXVARS)
		cerror("%s:  out of table space, max variables is %d\n",
			arg0,MAXVARS);

	initvar(varname,nvars,name);
	initvar(varvalue,nvars,value);
	++nvars;

	return(0);	/* success */
}

lookup(s)
/* look up s in var/value table, -1 if not found, otherwise
** index into table
*/
char *s;
{
	register int i;
	boolean found = false;

#ifdef	DEBUG
	if (debug(3))
		printf("lookup, s='%s'\n",s);
#endif

	for (i=0; i<nvars; i++)
		if (streq(s,varname[i])) {
			found = true;
			break;
		}
	
	if (found) {
#ifdef	DEBUG
		if (debug(3))
			printf("lookup: %s= '%s'\n",varname[i],varvalue[i]);
#endif
		return(i);
	}

	return(-1);
}
/******************************** parsemakemf.c ********************************/

int sc;

/*
** define the "escape" char for quoted strings, etc:
*/
#ifdef	MPWTOOL
	char BACKSLASH = (char) 0xb6;
#else
	char BACKSLASH = '\\';
#endif

int linecnt = 1;	/* current line number */
int charcnt = 0;	/* current character cnt within current line */

char yytext[MAX_LINE];
char linebuf[MAX_LINE];

char idstart[] =
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@.$(){}";
char idcont[] =
"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_@.$(){}0123456789";

char puncset[] = "=";
char wspace[] = " \t";
char begcomment = '#';

#define	SCAN()	tok=yylex()

boolean
parsemakemf()
/*
**	G	-> statement*
**	
**	statement
**		-> '<iden>' '=' text EOL
**	
**	text	-> '<any_but_EOL>'*
**	
**	NOTES:
**	
**	- contiuation lines are allowed via back-slash escaped newline.
**	- shell style comments may appear anywhere except in '<text>'.
*/
{
	/* initialize scanner, set current scan char (sc): */
	if (!scan())
		return(true);	/* empty file is okay */

	SCAN();		/* get first token */

	while (statement())
		;

	if (tok == EOF)
		return(true);	/* success if we made it to EOF */
	else {
		yywarn("syntax error\n");
		return(false);
	}
}

boolean
statement()
/*
**	statement
**		-> '<iden>' '=' text EOL
**		-> EOL
*/
{
	char buf[MAX_LINE];

	if (tok == EOL) {		/* empty statement? */
		SCAN();
		return(true);
	}

	if (tok != IDENTIFIER)
		return(false);

	/* save variable name: */
	strcpy(buf,yytext);

	SCAN();
	if (tok != PUNC || yytext[0] != '=')
		return(false);

	/* since text includes everything, must call it explicitly
	** text() does the scan:
	*/
	if (text()) {
#ifdef	DEBUG
		if (debug(31))
			fprintf(stderr,"lex returned (TEXT>%s<)\n",yytext);
#endif
	}

	/* save value: */
	addvar(buf,yytext);

	SCAN();
	if (tok == EOL) {
		SCAN();
		return(true);
	}

	return (false);
}

/*********************************** util.c  ***********************************/

char *
basename(s)
/* return a pointer to the beginning of the last word in a pathname
** Example, if s is "/tmp/foo", returns pointer to "foo"
*/
register char *s;
{
	register int i;

	/* find end of string: */
	for (i=0; *s != '\0'; i++)
		++s;
	/* look back for first pathname separator: */
	for (; *s != '/' && i>=0; i--)
		--s;

	++s;
	return(s);
}

boolean
append(f1,f2)
/* append f2 to f1.
** f1 must be positioned at end for writing,
** f2 must be positioned at beginning for reading.
** on exit, files are left in the same state.
*/
FILE *f1, *f2;
{
	int c;

	errno=0;
	while((c = getc(f2)) != EOF)
		putc(c,f1);

	if (errno) {
		fprintf(stderr, "append():  ");
		perror("util.c - append:");
		return(false);
	}

	fflush(f1);
	rewind(f2);
	return(true);
}

/*********************************** yyout.c ***********************************/

boolean yesyyout = false;

yyout(c)
/* define this if you want to ouput comments, etc */
int c;
{
	if (yesyyout )
		putc(c,yyoutf);
}

yyout_on()
/* turn on yyout() */
{
	yesyyout = true;
}

yyout_off()
/* turn off yyout() */
{
	yesyyout = false;
}

/******************************** barcomment.c  ********************************/

boolean
barcomment()
/* looks for a bar (|) comment.
** NOTE:
** If comment echoing is desired, define yyout() to output a character:
**	yyout(c) int c; { putchar(c);}
** otherwise, define as a null procedure:
**	yyout(c) int c; {}
*/
{
	if (wsp())	/* skip white space */
		;

	if (sc != '|')
		return(false);

	yyout('|');

	scan();		/* skip past semi-colon */

	while (sc != EOF && sc != '\n') {
		yyout(sc);
		scan();
	}

	/* NOTE:  don't skip or output newline */

	return(true);
}

/********************************** comment.c **********************************/



boolean comment()
/* looks for a C-style comment.
**
** NOTE:
** If comment echoing is desired, define yyout() to output a character:
**	yyout(c) int c; { putchar(c);}
** otherwise, define as a null procedure:
**	yyout(c) int c; {}
*/
{
	if (wsp())	/* skip white space */
		;

	if (sc != '/')
		return(false);

	scan();

	if (sc == '*')
	{
		yyout('/');
		/* have comment start */
		while (sc != EOF)
		{
			yyout(sc);
			scan();
			if (sc == '*')
			{
				scan();
				if (sc == '/')
				{
					yyout('*');
					yyout('/');
					scan();
					return(true);
				}
				else
				{ 
					unscan(); 
					sc = '*'; 
				}
			}
		}
	}
	else /* have to push back non-star char */
	{
		unscan();
		sc = '/';
	}

	return(false);	/* only happens on EOF if had comment start */
}

/************************************ eol.c ************************************/



boolean eol()
/* looks for eol as defined in lex.gram */
{
  int i = 0;

  if (wsp())	/* skip white space */
    ;

  if (sc != '\n')
    return(false);

  yyout(sc);		/* output whitespace */
  yytext[i++] = sc;
  scan();

  yytext[i++] = '\0';
  return(true);
}

/*********************************** inset.c ***********************************/


inset(c,s)
/* true if c is in the string s */
char c,s[];
{
  int i;

  for(i=0;s[i] != '\0'; ++i)
    if (s[i] == c)
      return(true);

  return(false);
}

/*********************************** ishex.c ***********************************/



boolean myishex()
/* looks for MPW hex string */
{
	int i = 0;

	if (wsp())	/* skip white space */
		;

	if (sc != '$')
		return(false);

	scan();
	if (ishexdigit(sc))
	{
		yytext[i++] = sc;
		scan();
		while (ishexdigit(sc))
		{
			yytext[i++] = sc;
			scan();
		}
		yytext[i++] = '\0';
		return(true);
	}
	else {
		unscan();	/* push non-hex digit back */
		sc = '$';	/* reset scan */
	}

	yytext[i++] = '\0';
	return(false);
}

ishexdigit(c)
int c;
{
	return(isdigit(c) || inrange('A',c,'F') || inrange('a',c,'f'));
}

/********************************** isiden.c  **********************************/



boolean isiden()
/* looks for identifier as defined in lex.gram */
{
  int i = 0;

  if (wsp())	/* skip white space */
    ;

  if (inset(sc,idstart))
    yytext[i++] = sc;
  else
    return(false);

  scan();

  while (inset(sc,idcont))
  {
    yytext[i++] = sc;
    scan();
  }

  yytext[i++] = '\0';
  return(true);
}

/*********************************** isint.c ***********************************/



boolean isint()
/* same as isinty(), but doesn't allow '+' or '-'.  used by mpwlex
*/
{
  int i = 0;

  if (wsp())	/* skip white space */
    ;

  if (isdigit(sc))
  {
    yytext[i++] = sc;
    scan();
    while (isdigit(sc))
    {
      yytext[i++] = sc;
      scan();
    }
    yytext[i++] = '\0';
    return(true);
  }

  yytext[i++] = '\0';
  return(false);
}

/********************************** isinty.c  **********************************/



boolean isinty()
/* looks for integer as defined in lex.gram (for yacc only) */
{
  int i = 0;

  if (wsp())	/* skip white space */
    ;

  if (sc == '-' || sc == '+')
  {
    yytext[i++] = sc;
    scan();
    if (wsp())	/* skip white space */
      ;
  }

  if (isdigit(sc))
  {
    yytext[i++] = sc;
    scan();
    while (isdigit(sc))
    {
      yytext[i++] = sc;
      scan();
    }
    yytext[i++] = '\0';
    return(true);
  }

  yytext[i++] = '\0';
  return(false);
}

/********************************** islabel.c **********************************/



boolean islabel()
/* looks for assembly label - which must start in column 1 */
{
  int i = 0;

  if (wsp())	/* skip white space */
    ;

  if (charcnt != 1)
    return(false);

  if (inset(sc,idstart))
    yytext[i++] = sc;
  else
    return(false);

  scan();

  while (inset(sc,idcont))
  {
    yytext[i++] = sc;
    scan();
  }

  yytext[i++] = '\0';
  return(true);
}

/******************************** linecomment.c ********************************/



boolean
linecomment()
/* looks for a line-style comment, i.e., a comment starting with
** some charater, and continuing to the end of the line.
**
** NOTE:
** If comment echoing is desired, define yyout() to output a character:
**	yyout(c) int c; { putchar(c);}
** otherwise, define as a null procedure:
**	yyout(c) int c; {}
*/
{
	if (wsp())	/* skip white space */
		;

	if (sc != begcomment)
		return(false);

	yyout(begcomment);

	scan();		/* skip past begin char */

	while (sc != EOF && sc != '\n') {
		yyout(sc);
		scan();
	}

	/* NOTE:  don't skip or output newline */

	return(true);
}

/*********************************** punc.c  ***********************************/



boolean punc()
/* looks for punc as defined in lex.gram */
{
  int i = 0;

  if (wsp())	/* skip white space */
    ;

  if (!inset(sc,puncset))
    return(false);

  yytext[i++] = sc;
  scan();

  yytext[i++] = '\0';
  return(true);
}

/********************************** q_char.c  **********************************/



boolean q_char()
/* looks for q_char as defined in lex.gram */
{
  int i = 0;

  if (wsp())	/* skip white space */
    ;

  if (sc != '\'')
    return(false);

  scan();
  if (sc == '\\')		/* save, regardless */
  {
    scan();
    yytext[i++] = sc;
  }
  else
    yytext[i++] = sc;

  scan();
  if (sc != '\'')
    yyerror("quoted char missing trailing quote.\n");

  yytext[i++] = '\0';
  scan();
  return(true);
}

/*********************************** scan.c  ***********************************/




static boolean eofset = false;

resetscan()
/* reinit scan for new parse */
{
	eofset = false;
	linecnt = 1;	/* current line number */
	charcnt = 0;	/* current character cnt within current line */
}

scan()
/* gets charaters from *yyin file */
{
  int c;

  if (debug(35) && charcnt > 10)
    printf("scan entry: sc=%c, linecnt=%d, charcnt=%d\n",sc,linecnt,charcnt);

  if (debug(32))
    printf("scan entry: sc=%c, linecnt=%d, charcnt=%d\n",sc,linecnt,charcnt);

  if (eofset)
  {
    sc = EOF;
    if (debug(32))
      printf("sc=EOF, linecnt=%d, charcnt=%d\n",linecnt,charcnt);
    return (false);
  }

  c = getc(yyin);
  if (c == EOF)
  {
    eofset = true;
    sc = EOF;
    if (debug(32))
      printf("sc=EOF, linecnt=%d, charcnt=%d\n",linecnt,charcnt);
    return (false);
  }

  /* otherwise, return true, set sc to c */
  sc = c;
  if (charcnt >= MAX_LINE-1)
    cerror("scan: line %d: line too long (cnt=%d, sc=%x hex).\n",
	linecnt,charcnt,sc);

  if (sc == '\n')
  {
    ++linecnt;
    linebuf[0] = '\0';
    charcnt = 0;
  }
  else
  {
    linebuf[charcnt++] = sc;
    linebuf[charcnt] = '\0';
  }

  if (debug(32))
    printf("sc=%c, linecnt=%d, charcnt=%d\n",sc,linecnt,charcnt);
  return(true);
}

/******************************** semicomment.c ********************************/



boolean semicomment()
/* looks for a semi-colon comment
** NOTE:
** If comment echoing is desired, define yyout() to output a character:
**	yyout(c) int c; { putchar(c);}
** otherwise, define as a null procedure:
**	yyout(c) int c; {}
*/
{
	if (wsp())	/* skip white space */
		;

	if (sc != ';')
		return(false);

	yyout('|');

	scan();		/* skip past semi-colon */

	while (sc != EOF && sc != '\n') {
		yyout(sc);
		scan();
	}

	/* NOTE:  don't skip or output newline */

	return(true);
}

/********************************** string.c  **********************************/



boolean string()
/* looks for string as defined in lex.gram */
{
  int i = 0;

  if (wsp())	/* skip white space */
    ;

  if (sc != '"')
    return(false);

  scan();

  while (sc != '"' && sc != EOF)
  {
    if (sc == '\n')
      yyerror("unescaped newline not allowed in string\n");
    if (sc == '\\')
    {
      scan();		/* get next char, whatever it is */
      if (sc == EOF)
      {
        yytext[i++] = sc;	/* save back-slash and return */
	return(false);
      }
      else
      if (sc == '\n')		/* ignore escaped newlines */
	;
      else	/* preserve literal sequence - any string processing
		 * must be done later. */
      {
        yytext[i++] = '\\';
        yytext[i++] = sc;
      }
    }
    else	/* not a back-slash */
      yytext[i++] = sc;

    scan();
  }

  if (sc == EOF)
    return(false);

  scan();	/* skip " char */
  yytext[i++] = '\0';
  return(true);
}

/*********************************** text.c  ***********************************/

extern char BACKSLASH;	/* line escape character */
extern int sc;		/* current scan char */
extern char yytext[];

boolean
text()
/* looks for a '<text>', which is everything to the end of line,
** except leading white space
**
** NOTE:
** User must not define wspace[] to contain newline, otherwise <text>
** will eat up everything to end of following line.
*/
{
	register int i = 0;

	if (sc == EOF)
		return(false);

	if (wsp())	/* skip white space */
		;

	while (sc != EOF && sc != '\n') {
		if (sc == BACKSLASH) {
			yytext[i++] = sc;	/* save back-slash */
			scan();		/* get next char, even if newline*/
			if (sc == EOF)
				return(false);
		}
		yytext[i++] = sc;
		scan();
	}

	yytext[i++] = '\0';

	return(true);
}

/********************************** unscan.c  **********************************/

unscan()
/* push back last char scanned
**	usage:
**	if (sc != MYCHAR) {
**		unscan();	# put current char back
**		sc = LASTCHAR;	# up to caller to remember last char
**	}
*/
{
  if (debug(34))
    printf("unscan: entry: sc='%c',charcnt=%d\n",sc,charcnt);
  ungetc(sc,yyin);
  if (charcnt > 0)
  {
    --charcnt;
    linebuf[charcnt] = '\0';
  }
  if (sc == '\n')
    --linecnt;
  if (debug(34))
    printf("unscan: exit: sc='%c',charcnt=%d\n",sc,charcnt);
}

/************************************ wsp.c ************************************/



wsp()
/*
** recognizes white space.
**
** NOTES:
** User must define wspace[] to contain characters to be considered
** as spaces.  For example, some programs may not consider linebreaks
** to be white-space.
**
** If comment echoing is desired, define yyout() to output a character:
**	yyout(c) int c; { putchar(c);}
** otherwise, define as a null procedure:
**	yyout(c) int c; {}
*/
{
  if (!inset(sc,wspace))
    return(false);

  while (inset(sc,wspace)) {
    yyout(sc);
    scan();
  }

  return(true);
}

/********************************** yyerror.c **********************************/



yyerror(f,a1,a2,a3,a4)
char *f,*a1,*a2,*a3,*a4;
{
	yyprint(f,a1,a2,a3,a4);
	exit(-1);
}

yywarn(f,a1,a2,a3,a4)
char *f,*a1,*a2,*a3,*a4;
{
	yyprint(f,a1,a2,a3,a4);
}

int
yyprint(f,a1,a2,a3,a4)
/* print parser error message */
char *f,*a1,*a2,*a3,*a4;
{
  int i;

  if (debug(40))
    printf("yyprint: linecnt=%d charcnt=%d\n",linecnt,charcnt);

  fprintf(stderr,"Line #%d:\n%s\n",linecnt,linebuf);

  /* print pointer as to where scan stopped */
  for (i=0; i < charcnt-1; ++i)
  {
    if (linebuf[i] == '\0')
      break;
    else if (linebuf[i] == '\t')
      putc('\t',stderr);
    else
      putc(' ',stderr);
  }

  fprintf(stderr,"^\n");

  fprintf(stderr,f,a1,a2,a3,a4);
}

/********************************** bugmod.c  **********************************/

#define MAXDEBUG 50

static int debugsw[MAXDEBUG];

debug(i)
int i;
{
	if (i>=0 && i<= MAXDEBUG-1)
		return(debugsw[i]);
	else
		cerror("Debug:  bad switch value.\n","");

	return(-1);
}

#ifdef	DEBUG
pollbug(ac,av)
/* if -bug is first argument, get debug switch settings from stdin,
** reset ac(argc), and shift argv to make debug flag invisible to
** remainder of calling (main) routine.
*/
int *ac;
char *av[];
{
	int i;
	char ln[30];

	/* reset all switches to 0 */
	for(i=0;i<=MAXDEBUG-1;++i)
		debugsw[i] = 0;

	if (*ac <= 1)		/* any args? */
		return;

	if ((strcmp(av[1],"-bug") != 0))
		return;

	/* shift args */
	for (i=2;i<= *ac-1; ++i) {
		/* if new arg is too big,
		** malloc enough space:
		*/
		if (strlen(av[i-1]) < strlen(av[i]))
			av[i-1]= malloc(strlen(av[i]));

		strcpy(av[i-1],av[i]);
	}

	/* adjust argc: */
	*ac = *ac - 1;

	for(;;)
	{
		printf("Debug? (#/q): ");
		gets(ln);
		if (sscanf(ln,"%d",&i) == 1)
		{
			if (i < 0)
				break;

			if (i <= MAXDEBUG-1)
				debugsw[i] = 1;		/* true */
			else
				printf("Switches range from 0 to %d.\n",
					MAXDEBUG-1);
		}
	}
}
#endif

/********************************* lowercase.c *********************************/


lowercase(text)
/* convert text to lower-case
 */
char text[];
{
  int i;

  for (i=0;i<strlen(text);++i)
    if (isupper(text[i]))
      text[i] = tolower(text[i]);
}
