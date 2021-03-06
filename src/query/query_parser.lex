%{
/*
 *	(C) Searchdaimon 2004-2014, Written by Magnus Gal�en, Runar Buvik
 *
 *	juni 2014: Tilater + og # inne i ord (men ikke i begynnelsen).
 *	juli 2008: Portet til ds pga. en bug/begrensning i lex.
 *	juni 2008: La til full støtte for utf-8-bokstaver.
 *	mai 2007: La til st�tte for OR. Syntax: Skriv | foran ord eller frase som skal OR-es. OR og NOT samtidig fungerer ikke.
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../ds/dcontainer.h"
#include "../ds/dpair.h"
#include "../ds/dvector.h"
#include "../ds/dset.h"

#include "../common/utf8-strings.h"
#include "../common/bprint.h"
#include "../common/xml.h"

#include "query_parser.h"


static inline query_array _query_array_init( int n );
static inline void _query_array_destroy( query_array qa );
static inline string_array _string_array_init( int n );
static inline void _string_array_destroy( string_array sa );
static inline int _qp_next_( yyscan_t yyscanner );


struct _qp_yy_extra
{
    container	*big, *sequence;
    char	operand, in_phrase, space;
};

/*
    Spesialtilfeller:

	Velger � tolke [ ole-"dole" ] som [ ole -"dole" ]
	Dersom avsluttende parentes mangler, tolker vi det som det skulle v�rt en etter siste ord i query-et.
*/

#define YY_EXTRA_TYPE	struct _qp_yy_extra*

%}

letter		[0-9a-zA-Z_��������������������������������������������������������������]
infix		['`]
phrase_cat	[\.,@]
space		[\ \t]
u8a		([\101-\132]|[\141-\172]|\302\252|\302\265|\302\272|\303[\200-\226]|\303[\230-\266]|\303[\270-\277]|[\304-\312][\200-\277]|\313[\200-\201]|\313[\206-\221]|\313[\240-\244]|\313\254|\313\256|\315\205|\315[\260-\264]|\315[\266-\267]|\315[\272-\275]|\316\206|\316[\210-\212]|\316\214|\316[\216-\241]|\316[\243-\277]|\317[\200-\265]|\317[\267-\277]|[\320-\321][\200-\277]|\322[\200-\201]|\322[\212-\277]|\324[\200-\243]|\324[\261-\277]|\325[\200-\226]|\325\231|\325[\241-\277]|\326[\200-\207]|\326[\260-\275]|\326\277|\327[\201-\202]|\327[\204-\205]|\327\207|\327[\220-\252]|\327[\260-\262]|\330[\220-\232]|\330[\241-\277]|\331[\200-\227]|\331[\231-\236]|\331[\256-\277]|\333[\200-\223]|\333[\225-\234]|\333[\241-\250]|\333[\255-\257]|\333[\272-\274]|\333\277|\334[\220-\277]|\335[\215-\277]|\336[\200-\261]|\337[\212-\252]|\337[\264-\265]|\337\272|\340\244[\201-\271]|\340\244[\275-\277]|\340\245[\200-\214]|\340\245\220|\340\245[\230-\243]|\340\245[\261-\262]|\340\245[\273-\277]|\340\246[\201-\203]|\340\246[\205-\214]|\340\246[\217-\220]|\340\246[\223-\250]|\340\246[\252-\260]|\340\246\262|\340\246[\266-\271]|\340\246[\275-\277]|\340\247[\200-\204]|\340\247[\207-\210]|\340\247[\213-\214]|\340\247\216|\340\247\227|\340\247[\234-\235]|\340\247[\237-\243]|\340\247[\260-\261]|\340\250[\201-\203]|\340\250[\205-\212]|\340\250[\217-\220]|\340\250[\223-\250]|\340\250[\252-\260]|\340\250[\262-\263]|\340\250[\265-\266]|\340\250[\270-\271]|\340\250[\276-\277]|\340\251[\200-\202]|\340\251[\207-\210]|\340\251[\213-\214]|\340\251\221|\340\251[\231-\234]|\340\251\236|\340\251[\260-\265]|\340\252[\201-\203]|\340\252[\205-\215]|\340\252[\217-\221]|\340\252[\223-\250]|\340\252[\252-\260]|\340\252[\262-\263]|\340\252[\265-\271]|\340\252[\275-\277]|\340\253[\200-\205]|\340\253[\207-\211]|\340\253[\213-\214]|\340\253\220|\340\253[\240-\243]|\340\254[\201-\203]|\340\254[\205-\214]|\340\254[\217-\220]|\340\254[\223-\250]|\340\254[\252-\260]|\340\254[\262-\263]|\340\254[\265-\271]|\340\254[\275-\277]|\340\255[\200-\204]|\340\255[\207-\210])
u8b		(\340\255[\213-\214]|\340\255[\226-\227]|\340\255[\234-\235]|\340\255[\237-\243]|\340\255\261|\340\256[\202-\203]|\340\256[\205-\212]|\340\256[\216-\220]|\340\256[\222-\225]|\340\256[\231-\232]|\340\256\234|\340\256[\236-\237]|\340\256[\243-\244]|\340\256[\250-\252]|\340\256[\256-\271]|\340\256[\276-\277]|\340\257[\200-\202]|\340\257[\206-\210]|\340\257[\212-\214]|\340\257\220|\340\257\227|\340\260[\201-\203]|\340\260[\205-\214]|\340\260[\216-\220]|\340\260[\222-\250]|\340\260[\252-\263]|\340\260[\265-\271]|\340\260[\275-\277]|\340\261[\200-\204]|\340\261[\206-\210]|\340\261[\212-\214]|\340\261[\225-\226]|\340\261[\230-\231]|\340\261[\240-\243]|\340\262[\202-\203]|\340\262[\205-\214]|\340\262[\216-\220]|\340\262[\222-\250]|\340\262[\252-\263]|\340\262[\265-\271]|\340\262[\275-\277]|\340\263[\200-\204]|\340\263[\206-\210]|\340\263[\212-\214]|\340\263[\225-\226]|\340\263\236|\340\263[\240-\243]|\340\264[\202-\203]|\340\264[\205-\214]|\340\264[\216-\220]|\340\264[\222-\250]|\340\264[\252-\271]|\340\264[\275-\277]|\340\265[\200-\204]|\340\265[\206-\210]|\340\265[\212-\214]|\340\265\227|\340\265[\240-\243]|\340\265[\272-\277]|\340\266[\202-\203]|\340\266[\205-\226]|\340\266[\232-\261]|\340\266[\263-\273]|\340\266\275|\340\267[\200-\206]|\340\267[\217-\224]|\340\267\226|\340\267[\230-\237]|\340\267[\262-\263]|\340\270[\201-\272]|\340\271[\200-\206]|\340\271\215|\340\272[\201-\202]|\340\272\204|\340\272[\207-\210]|\340\272\212|\340\272\215|\340\272[\224-\227]|\340\272[\231-\237]|\340\272[\241-\243]|\340\272\245|\340\272\247|\340\272[\252-\253]|\340\272[\255-\271]|\340\272[\273-\275]|\340\273[\200-\204]|\340\273\206|\340\273\215|\340\273[\234-\235]|\340\274\200|\340\275[\200-\207]|\340\275[\211-\254]|\340\275[\261-\277]|\340\276[\200-\201]|\340\276[\210-\213]|\340\276[\220-\227]|\340\276[\231-\274]|\341\200[\200-\266]|\341\200\270|\341\200[\273-\277]|\341\201[\220-\242]|\341\201[\245-\250]|\341\201[\256-\277]|\341\202[\200-\206]|\341\202\216|\341\202[\240-\277]|\341\203[\200-\205]|\341\203[\220-\272])
u8c		(\341\203\274|\341\204[\200-\277]|\341\205[\200-\231]|\341\205[\237-\277]|\341\206[\200-\242]|\341\206[\250-\277]|\341\207[\200-\271]|\341\210[\200-\277]|\341\211[\200-\210]|\341\211[\212-\215]|\341\211[\220-\226]|\341\211\230|\341\211[\232-\235]|\341\211[\240-\277]|\341\212[\200-\210]|\341\212[\212-\215]|\341\212[\220-\260]|\341\212[\262-\265]|\341\212[\270-\276]|\341\213\200|\341\213[\202-\205]|\341\213[\210-\226]|\341\213[\230-\277]|\341\214[\200-\220]|\341\214[\222-\225]|\341\214[\230-\277]|\341\215[\200-\232]|\341\215\237|\341\216[\200-\217]|\341\216[\240-\277]|\341\217[\200-\264]|\341\220[\201-\277]|\341[\221-\230][\200-\277]|\341\231[\200-\254]|\341\231[\257-\266]|\341\232[\201-\232]|\341\232[\240-\277]|\341\233[\200-\252]|\341\233[\256-\260]|\341\234[\200-\214]|\341\234[\216-\223]|\341\234[\240-\263]|\341\235[\200-\223]|\341\235[\240-\254]|\341\235[\256-\260]|\341\235[\262-\263]|\341\236[\200-\263]|\341\236[\266-\277]|\341\237[\200-\210]|\341\237\227|\341\237\234|\341\240[\240-\277]|\341\241[\200-\267]|\341\242[\200-\252]|\341\244[\200-\234]|\341\244[\240-\253]|\341\244[\260-\270]|\341\245[\220-\255]|\341\245[\260-\264]|\341\246[\200-\251]|\341\246[\260-\277]|\341\247[\200-\211]|\341\250[\200-\233]|\341\254[\200-\263]|\341\254[\265-\277]|\341\255[\200-\203]|\341\255[\205-\213]|\341\256[\200-\251]|\341\256[\256-\257]|\341\260[\200-\265]|\341\261[\215-\217]|\341\261[\232-\275]|\341[\264-\266][\200-\277]|\341\270[\200-\277]|\341[\271-\273][\200-\277]|\341\274[\200-\225]|\341\274[\230-\235]|\341\274[\240-\277]|\341\275[\200-\205]|\341\275[\210-\215]|\341\275[\220-\227]|\341\275\231|\341\275\233|\341\275\235|\341\275[\237-\275]|\341\276[\200-\264]|\341\276[\266-\274]|\341\276\276|\341\277[\202-\204]|\341\277[\206-\214]|\341\277[\220-\223]|\341\277[\226-\233]|\341\277[\240-\254]|\341\277[\262-\264]|\341\277[\266-\274]|\342\201\261|\342\201\277|\342\202[\220-\224]|\342\204\202|\342\204\207|\342\204[\212-\223]|\342\204\225|\342\204[\231-\235]|\342\204\244|\342\204\246|\342\204\250|\342\204[\252-\255])
u8d		(\342\204[\257-\271]|\342\204[\274-\277]|\342\205[\205-\211]|\342\205\216|\342\205[\240-\277]|\342\206[\200-\210]|\342\222[\266-\277]|\342\223[\200-\251]|\342\260[\200-\256]|\342\260[\260-\277]|\342\261[\200-\236]|\342\261[\240-\257]|\342\261[\261-\275]|\342\262[\200-\277]|\342\263[\200-\244]|\342\264[\200-\245]|\342\264[\260-\277]|\342\265[\200-\245]|\342\265\257|\342\266[\200-\226]|\342\266[\240-\246]|\342\266[\250-\256]|\342\266[\260-\266]|\342\266[\270-\276]|\342\267[\200-\206]|\342\267[\210-\216]|\342\267[\220-\226]|\342\267[\230-\236]|\342\267[\240-\277]|\342\270\257|\343\200[\205-\207]|\343\200[\241-\251]|\343\200[\261-\265]|\343\200[\270-\274]|\343\201[\201-\277]|\343\202[\200-\226]|\343\202[\235-\237]|\343\202[\241-\277]|\343\203[\200-\272]|\343\203[\274-\277]|\343\204[\205-\255]|\343\204[\261-\277]|\343\206[\200-\216]|\343\206[\240-\267]|\343\207[\260-\277]|\343[\220-\277][\200-\277]|\344[\200-\265][\200-\277]|\344\266[\200-\265]|\344[\270-\277][\200-\277]|[\345-\350][\200-\277][\200-\277]|\351[\200-\276][\200-\277]|\351\277[\200-\203]|\352[\200-\221][\200-\277]|\352\222[\200-\214]|\352\224[\200-\277]|\352[\225-\227][\200-\277]|\352\230[\200-\214]|\352\230[\220-\237]|\352\230[\252-\253]|\352\231[\200-\237]|\352\231[\242-\256]|\352\231[\277-\277]|\352\232[\200-\227]|\352\234[\227-\237]|\352\234[\242-\277]|\352\236[\200-\210]|\352\236[\213-\214]|\352\237[\273-\277]|\352\240[\200-\201]|\352\240[\203-\205]|\352\240[\207-\212]|\352\240[\214-\247]|\352\241[\200-\263]|\352\242[\200-\277]|\352\243[\200-\203]|\352\244[\212-\252]|\352\244[\260-\277]|\352\245[\200-\222]|\352\250[\200-\266]|\352\251[\200-\215]|\352[\260-\277][\200-\277]|[\353-\354][\200-\277][\200-\277]|\355[\200-\235][\200-\277]|\355\236[\200-\243]|\357\244[\200-\277]|\357[\245-\247][\200-\277]|\357\250[\200-\255]|\357\250[\260-\277]|\357\251[\200-\252]|\357\251[\260-\277]|\357\253[\200-\231]|\357\254[\200-\206]|\357\254[\223-\227]|\357\254[\235-\250]|\357\254[\252-\266]|\357\254[\270-\274]|\357\254\276|\357\255[\200-\201]|\357\255[\203-\204])
u8e		(\357\255[\206-\277]|\357\256[\200-\261]|\357\257[\223-\277]|\357[\260-\263][\200-\277]|\357\264[\200-\275]|\357\265[\220-\277]|\357\266[\200-\217]|\357\266[\222-\277]|\357\267[\200-\207]|\357\267[\260-\273]|\357\271[\260-\264]|\357\271[\266-\277]|\357\273[\200-\274]|\357\274[\241-\272]|\357\275[\201-\232]|\357\275[\246-\277]|\357\276[\200-\276]|\357\277[\202-\207]|\357\277[\212-\217]|\357\277[\222-\227]|\357\277[\232-\234]|\360\220\200[\200-\213]|\360\220\200[\215-\246]|\360\220\200[\250-\272]|\360\220\200[\274-\275]|\360\220\200\277|\360\220\201[\200-\215]|\360\220\201[\220-\235]|\360\220\202[\200-\277]|\360\220\203[\200-\272]|\360\220\205[\200-\264]|\360\220\212[\200-\234]|\360\220\212[\240-\277]|\360\220\213[\200-\220]|\360\220\214[\200-\236]|\360\220\214[\260-\277]|\360\220\215[\200-\212]|\360\220\216[\200-\235]|\360\220\216[\240-\277]|\360\220\217[\200-\203]|\360\220\217[\210-\217]|\360\220\217[\221-\225]|\360\220\220[\200-\277]|\360\220\222[\200-\235]|\360\220\240[\200-\205]|\360\220\240\210|\360\220\240[\212-\265]|\360\220\240[\267-\270]|\360\220\240\274|\360\220\240\277|\360\220\244[\200-\225]|\360\220\244[\240-\271]|\360\220\250[\200-\203]|\360\220\250[\205-\206]|\360\220\250[\214-\223]|\360\220\250[\225-\227]|\360\220\250[\231-\263]|\360\222[\200-\214][\200-\277]|\360\222\215[\200-\256]|\360\222\220[\200-\277]|\360\222\221[\200-\242]|\360\235\220[\200-\277]|\360\235\221[\200-\224]|\360\235\221[\226-\277]|\360\235\222[\200-\234]|\360\235\222[\236-\237]|\360\235\222\242|\360\235\222[\245-\246]|\360\235\222[\251-\254]|\360\235\222[\256-\271]|\360\235\222\273|\360\235\222[\275-\277]|\360\235\223[\200-\203]|\360\235\223[\205-\277]|\360\235\224[\200-\205]|\360\235\224[\207-\212]|\360\235\224[\215-\224]|\360\235\224[\226-\234]|\360\235\224[\236-\271]|\360\235\224[\273-\276]|\360\235\225[\200-\204]|\360\235\225\206|\360\235\225[\212-\220]|\360\235\225[\222-\277]|\360\235[\226-\231][\200-\277]|\360\235\232[\200-\245]|\360\235\232[\250-\277]|\360\235\233[\200-\200]|\360\235\233[\202-\232])
u8f		(\360\235\233[\234-\272]|\360\235\233[\274-\277]|\360\235\234[\200-\224]|\360\235\234[\226-\264]|\360\235\234[\266-\277]|\360\235\235[\200-\216]|\360\235\235[\220-\256]|\360\235\235[\260-\277]|\360\235\236[\200-\210]|\360\235\236[\212-\250]|\360\235\236[\252-\277]|\360\235\237[\200-\202]|\360\235\237[\204-\213]|\360[\240-\251][\200-\277][\200-\277]|\360\252[\200-\232][\200-\277]|\360\252\233[\200-\226]|\360\257\240[\200-\277]|\360\257[\241-\247][\200-\277]|\360\257\250[\200-\235])
%option	noyywrap reentrant
%x PHRASE CMD CMD_PHRASE ATTRIBUTE_CMD ATTRIBUTE_CMD_PHRASE
%%
\+?[dD][aA][tT][eE]{space}*:	{ yyget_extra(yyscanner)->operand = 'd'; BEGIN CMD; }
\+?[sS][tT][aA][tT][uU][sS]{space}*:	{ yyget_extra(yyscanner)->operand = 's'; BEGIN CMD; }
\+?[fF][iI][lL][eE][tT][yY][pP][eE]{space}*:	{ yyget_extra(yyscanner)->operand = 'f'; BEGIN CMD; }
\+?[lL][aA][nN][gG][uU][aA][gG][eE]{space}*:	{ yyget_extra(yyscanner)->operand = 'l'; BEGIN CMD; }
\+?[cC][oO][lL][lL][eE][cC][tT][iI][oO][nN]{space}*:	{ yyget_extra(yyscanner)->operand = 'c'; BEGIN CMD; }
\+?[sS][oO][rR][tT]{space}*: { yyget_extra(yyscanner)->operand = 'k'; BEGIN CMD; }
\+?[gG][rR][oO][uU][pP]{space}*: { yyget_extra(yyscanner)->operand = 'g'; BEGIN ATTRIBUTE_CMD; }
\+?[aA][tT][tT][rR][iI][bB][uU][tT][eE]{space}*: { yyget_extra(yyscanner)->operand = 'a'; BEGIN ATTRIBUTE_CMD; }
\+			{ yyget_extra(yyscanner)->operand = '+'; }
\-			{
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );
			    if (qe->space) qe->operand = '-';
			}
\|			{ yyget_extra(yyscanner)->operand = '|'; }
\"			{
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    if (_qp_next_(yyscanner)) qe->operand = '+';

			    if (qe->operand == '-') qe->operand = '~';
			    else if (qe->operand == '+') qe->operand = '"';
			    BEGIN PHRASE;
			}
<CMD>\"			{	/* epost-hack */
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    if (_qp_next_(yyscanner))
				{
				    qe->operand = '+';
				    BEGIN INITIAL;
				}

			    BEGIN CMD_PHRASE;
			}
<ATTRIBUTE_CMD>\"		{
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    if (_qp_next_(yyscanner))
				{
				    qe->operand = '+';
				    BEGIN INITIAL;
				}

			    BEGIN ATTRIBUTE_CMD_PHRASE;
			}
<PHRASE,CMD_PHRASE,ATTRIBUTE_CMD_PHRASE>\"	{
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    _qp_next_(yyscanner);

			    qe->operand = '+';
			    qe->space = 1;
			    BEGIN INITIAL;
			}
<CMD,ATTRIBUTE_CMD>({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f})({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f}|{infix}|\-)*({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f})		{
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    vector_pushback(qe->sequence, yytext);

			    qe->space = 0;
			    BEGIN INITIAL;
			}
<CMD_PHRASE>({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f})({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f}|{infix}|\-)*({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f})		{
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    vector_pushback(qe->sequence, yytext);

			    qe->space = 0;
			}
 /* <LITERAL_CMD_PHRASE>({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f})({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f}|{infix}|{literal_infix})*({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f})		{ */
<ATTRIBUTE_CMD_PHRASE>[^\"]* {
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    vector_pushback(qe->sequence, yytext);

			    qe->space = 0;
			}
<INITIAL,PHRASE>({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f})({letter}|{u8a}|{u8b}|{u8c}|{u8d}|{u8e}|{u8f}|{infix})*([\+#%]+)*		{
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    vector_pushback(qe->sequence, yytext);

			    qe->space = 0;
			}
{phrase_cat}+		{}
[\ \t\f\r\n]+		{
			    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

			    if (_qp_next_(yyscanner)) qe->operand = '+';

			    qe->space = 1;
			}
.			{ yyget_extra( yyscanner )->space = 0; }
<*>.|\n			{}
%%


// Initialiser og alloker et nytt query_array:
static inline query_array _query_array_init( int n )
{
    query_array		qa;

    qa.n = n;
    qa.query = malloc(sizeof(string_array[qa.n]));

    return qa;
}

// Frigj�r et gammelt query_array:
static inline void _query_array_destroy( query_array qa )
{
    free(qa.query);
}

// Initialiser og alloker et nytt string_array:
static inline string_array _string_array_init( int n )
{
    string_array	sa;

    sa.n = n;
    sa.s = malloc(sizeof(char*[sa.n]));
    sa.spelled = NULL;
    sa.alt = NULL;
    sa.hide = 0;

    return sa;
}

// Frigj�r et gammelt string_array:
static inline void _string_array_destroy( string_array sa )
{
    free(sa.s);

    if (sa.alt != NULL) free(sa.alt);
}


static inline int _qp_next_( yyscan_t yyscanner )
{
    struct _qp_yy_extra		*qe = yyget_extra( yyscanner );

    if (vector_size(qe->sequence) > 0)
	{
	    // _end_()
	    vector_pushback(qe->big, qe->operand);
	    value	_v = vector_get(qe->big, vector_size(qe->big)-1);
	    container	*_t = pair(_v).second.C;
	    pair(_v).second.C = qe->sequence;
	    vector_set(qe->big, vector_size(qe->big)-1, _v);
	    qe->sequence = _t;

	    return 1;
	}

    return 0;
}

// Tolker query i 'text', resultatet legges i 'qa':
void get_query( char text[], int text_size, query_array *qa )
{
    struct _qp_yy_extra		*qe = malloc(sizeof(struct _qp_yy_extra));
    int				i, j;

    #ifdef DEBUG
    fprintf(stderr, "query.parser: get_query(\"%s\")\n", text);
    #endif

    qe->big = vector_container( pair_container( int_container(), vector_container( string_container() ) ) );
    qe->sequence = vector_container( string_container() );
    qe->operand = '+';
    qe->space = 1;
    qe->in_phrase = 0;

    yyscan_t	scanner;

    yylex_init( &scanner );
    yyset_extra( qe, scanner );
    YY_BUFFER_STATE	bs = yy_scan_bytes( text, text_size, scanner );

    yylex( scanner );

    // I tilfelle en parantes ikke er avsluttet:
    _qp_next_(scanner);
    destroy(qe->sequence);

    yy_delete_buffer( bs, scanner );
    yylex_destroy( scanner );

    // Gj�r om querydata til en mer praktisk struktur (for direkteoppslag):

    (*qa) = _query_array_init( vector_size(qe->big) );

    for (i=0; i<vector_size(qe->big); i++)
	{
	    container	*crnt = pair(vector_get(qe->big, i)).second.C;

	    qa->query[i] = _string_array_init( vector_size(crnt) );

	    qa->query[i].operand = pair(vector_get(qe->big, i)).first.i;
	    qa->query[i].alt = NULL;
	    qa->query[i].alt_n = 0;

	    if (qa->query[i].operand=='+' && qa->query[i].n>1)
		qa->query[i].operand = '"';
	    else if (qa->query[i].operand=='-' && qa->query[i].n>1)
		qa->query[i].operand = '~';

	    for (j=0; j<vector_size(crnt); j++)
	        {
	            qa->query[i].s[j] = copy_latin1_to_utf8(vector_get(crnt,j).ptr);
	        }
	}

    destroy(qe->big);
    free(qe);
}


// Lager query_array av vector< pair< int, vector<string> > >:
void make_query_array( container *big, query_array *qa )
{
    int		i, j;
    // Gj�r om querydata til en mer praktisk struktur (for direkteoppslag):

    (*qa) = _query_array_init( vector_size(big) );

    for (i=0; i<vector_size(big); i++)
	{
	    container	*crnt = pair(vector_get(big, i)).second.C;

	    qa->query[i] = _string_array_init( vector_size(crnt) );

	    qa->query[i].operand = pair(vector_get(big, i)).first.i;
	    qa->query[i].alt = NULL;
	    qa->query[i].alt_n = 0;

	    for (j=0; j<vector_size(crnt); j++)
	        {
	            qa->query[i].s[j] = strdup(vector_get(crnt,j).ptr);
	        }
	}
}


/******************************************/

struct _qp_html_esc
{
    char	c, *esc;
};

struct _qp_html_esc _qp_he[65] = {
    {'�',"sup2"},{'�',"sup3"},{'�',"sup1"},{'�',"Agrave"},{'�',"Aacute"},{'�',"Acirc"},{'�',"Atilde"},{'�',"Auml"},
    {'�',"Aring"},{'�',"AElig"},{'�',"Ccedil"},{'�',"Egrave"},{'�',"Eacute"},{'�',"Ecirc"},{'�',"Euml"},{'�',"Igrave"},
    {'�',"Iacute"},{'�',"Icirc"},{'�',"Iuml"},{'�',"ETH"},{'�',"Ntilde"},{'�',"Ograve"},{'�',"Oacute"},{'�',"Ocirc"},
    {'�',"Otilde"},{'�',"Ouml"},{'�',"Oslash"},{'�',"Ugrave"},{'�',"Uacute"},{'�',"Ucirc"},{'�',"Uuml"},{'�',"Yacute"},
    {'�',"THORN"},{'�',"szlig"},{'�',"agrave"},{'�',"aacute"},{'�',"acirc"},{'�',"atilde"},{'�',"auml"},{'�',"aring"},
    {'�',"aelig"},{'�',"ccedil"},{'�',"egrave"},{'�',"eacute"},{'�',"ecirc"},{'�',"euml"},{'�',"igrave"},{'�',"iacute"},
    {'�',"icirc"},{'�',"iuml"},{'�',"eth"},{'�',"ntilde"},{'�',"ograve"},{'�',"oacute"},{'�',"ocirc"},{'�',"otilde"},
    {'�',"ouml"},{'�',"oslash"},{'�',"ugrave"},{'�',"uacute"},{'�',"ucirc"},{'�',"uuml"},{'�',"yacute"},{'�',"thorn"},
    {'�',"yuml"}};


int _qp_esc_compare(const void *a, const void *b)
{
    if (*((char*)a) < ((struct _qp_html_esc*)b)->c) return -1;
    if (*((char*)a) > ((struct _qp_html_esc*)b)->c) return +1;
    return 0;
}


char* _qp_convert_to_html_escapes( char *src )
{
    char	*dest;
    int		i, j, size=0;

    for (i=0; src[i]!='\0'; i++)
	{
	    if ((unsigned char)src[i]<128)
		{
		    size++;
		}
	    else
		{
		    struct _qp_html_esc	*p = (struct _qp_html_esc*)
		    bsearch( (const void*)(((char*)&(src[i]))), _qp_he, 65, sizeof(struct _qp_html_esc), _qp_esc_compare);

		    if (p==NULL)
			size++;
		    else
			size+= strlen(p->esc) +2;
		}
	}

    dest = malloc(size+1);

    for (i=0, j=0; src[i]!='\0'; i++)
	{
	    if ((unsigned char)src[i]<128)
		{
		    dest[j++] = src[i];
		}
	    else
		{
		    struct _qp_html_esc	*p = (struct _qp_html_esc*)
		    bsearch( (const void*)(((char*)&(src[i]))), _qp_he, 65, sizeof(struct _qp_html_esc), _qp_esc_compare);

		    if (p==NULL)
			dest[j++] = src[i];
		    else
			{
			    dest[j++] = '&';
			    strcpy( &(dest[j]), p->esc );
			    j+= strlen(p->esc);
			    dest[j++] = ';';
			}
		}
	}

    dest[size] = '\0';

    return dest;
}

/******************************************/

void copy_htmlescaped_query( query_array *qa_dest, query_array *qa_src )
{
    int		i, j;

    (*qa_dest) = _query_array_init( qa_src->n );

    for (i = 0; i<qa_src->n; i++)
	{
	    qa_dest->query[i] = _string_array_init( qa_src->query[i].n );
	    qa_dest->query[i].operand = qa_src->query[i].operand;

	    for (j = 0; j<qa_src->query[i].n; j++)
		{
		    qa_dest->query[i].s[j] = _qp_convert_to_html_escapes( qa_src->query[i].s[j] );
		}
	}
}


// Frigj�r data i 'qa':
void destroy_query( query_array *qa )
{
    int		i, j, k;

    for (i=0; i<qa->n; i++)
	{
	    for (j=0; j<qa->query[i].n; j++)
		{
		    free( qa->query[i].s[j] );	// Minnet her ble allokert av strdup.
		}

	    if (qa->query[i].alt != NULL)
		{
		    for (j=0; j<qa->query[i].alt_n; j++)
			{
			    for (k=0; k<qa->query[i].alt[j].n; k++)
				free( qa->query[i].alt[j].s[k] );
			    free( qa->query[i].alt[j].s );
			}
		}

	    _string_array_destroy( qa->query[i] );
	}

    _query_array_destroy( *qa );
}


void copy_query( query_array *dest, query_array *src )
{
    int		i, j;

    (*dest) = _query_array_init( src->n );

    for (i=0; i<src->n; i++)
	{
	    dest->query[i] = _string_array_init(src->query[i].n);
	    dest->query[i].operand = src->query[i].operand;

	    for (j=0; j<src->query[i].n; j++)
		{
		    dest->query[i].s[j] = strdup(src->query[i].s[j]);
		}
	}
}


void sprint_query( char *s, int n, query_array *qa )
{
    int		i, j;
    int		pos = 0;

    for (i=0; i<qa->n; i++)
	{
	    if (qa->query[i].hide) continue;
	    if (i>0) pos+= snprintf(s+pos, n - pos, " ");

	    switch (qa->query[i].operand)
		{
		    case QUERY_WORD:
			break;
		    case QUERY_SUB:
			pos+= snprintf(s+pos, n - pos, "-");
			break;
		    case QUERY_PHRASE:
			break;
		    case QUERY_SUBPHRASE:
			pos+= snprintf(s+pos, n - pos, "-");
			break;
		    case QUERY_FILETYPE:
			pos+= snprintf(s+pos, n - pos, "filetype:");
			break;
		    case QUERY_LANGUAGE:
			pos+= snprintf(s+pos, n - pos, "language:");
			break;
		    case QUERY_COLLECTION:
			pos+= snprintf(s+pos, n - pos, "collection:");
			break;
		    case QUERY_DATE:
			pos+= snprintf(s+pos, n - pos, "date:");
			break;
		    case QUERY_STATUS:
			pos+= snprintf(s+pos, n - pos, "status:");
			break;
		    case QUERY_OR:
			pos+= snprintf(s+pos, n - pos, "| ");
			break;
		    case QUERY_SORT:
			pos+= snprintf(s+pos, n - pos, "sort:");
			break;
		    case QUERY_GROUP:
			pos+= snprintf(s+pos, n - pos, "group:");
			break;
		    case QUERY_ATTRIBUTE:
			pos+= snprintf(s+pos, n - pos, "attribute:");
			break;
		}

	    if (qa->query[i].n > 1 || qa->query[i].operand == QUERY_PHRASE
		|| qa->query[i].operand == QUERY_GROUP
		|| qa->query[i].operand == QUERY_ATTRIBUTE) pos+= snprintf(s+pos, n - pos, "\"");

	    for (j=0; j<qa->query[i].n; j++)
		{
		    if (j>0)
			{
			    if (qa->query[i].operand == QUERY_ATTRIBUTE) pos+= snprintf(s+pos, n - pos, "=");
			    else pos+= snprintf(s+pos, n - pos, " ");
			}
		    pos+= snprintf(s+pos, n - pos, "%s", qa->query[i].s[j]);
		}

	    if (qa->query[i].n > 1 || qa->query[i].operand == QUERY_PHRASE
		|| qa->query[i].operand == QUERY_GROUP
		|| qa->query[i].operand == QUERY_ATTRIBUTE) pos+= snprintf(s+pos, n - pos, "\"");
	}

    if (pos < n) s[pos] = '\0';
    else s[n-1] = '\0';
}


char* asprint_query( query_array *qa )
{
    int		i, j;
    buffer	*B = buffer_init(-1);

    for (i=0; i<qa->n; i++)
	{
	    if (qa->query[i].hide) continue;
	    if (i>0) bprintf(B, " ");

	    switch (qa->query[i].operand)
		{
		    case QUERY_WORD:
			break;
		    case QUERY_SUB:
			bprintf(B, "-");
			break;
		    case QUERY_PHRASE:
			break;
		    case QUERY_SUBPHRASE:
			bprintf(B, "-");
			break;
		    case QUERY_FILETYPE:
			bprintf(B, "filetype:");
			break;
		    case QUERY_LANGUAGE:
			bprintf(B, "language:");
			break;
		    case QUERY_COLLECTION:
			bprintf(B, "collection:");
			break;
		    case QUERY_DATE:
			bprintf(B, "date:");
			break;
		    case QUERY_STATUS:
			bprintf(B, "status:");
			break;
		    case QUERY_OR:
			bprintf(B, "| ");
			break;
		    case QUERY_SORT:
			bprintf(B, "sort:");
			break;
		    case QUERY_GROUP:
			bprintf(B, "group:");
			break;
		    case QUERY_ATTRIBUTE:
			bprintf(B, "attribute:");
			break;
		}

	    if (qa->query[i].n > 1 || qa->query[i].operand == QUERY_PHRASE
		|| qa->query[i].operand == QUERY_GROUP
		|| qa->query[i].operand == QUERY_ATTRIBUTE) bprintf(B, "\"");

	    for (j=0; j<qa->query[i].n; j++)
		{
		    if (j>0)
			{
			    if (qa->query[i].operand == QUERY_ATTRIBUTE) bprintf(B, "=");
			    else bprintf(B, " ");
			}
		    bprintf(B, "%s", qa->query[i].s[j]);
		}

	    if (qa->query[i].n > 1 || qa->query[i].operand == QUERY_PHRASE
		|| qa->query[i].operand == QUERY_GROUP
		|| qa->query[i].operand == QUERY_ATTRIBUTE) bprintf(B, "\"");
	}

    return buffer_exit(B);
}


int bsprint_query_with_remove( buffer *B, container *remove, query_array *qa, int escape )
{
    int		i, j;
    iterator	it;
    char	all_gone = 1;

    if (remove==NULL) it.valid = 0;
    else it = set_begin(remove);

    if (it.valid && set_key(it).i == -1)
	it = set_next(it);

    for (i=0; i<qa->n; i++)
	{
	    if (it.valid && set_key(it).i == i)
		{
		    it = set_next(it);
		    continue;
		}
	    else all_gone = 0;

	    if (qa->query[i].hide) continue;

	    if (i>0) bprintf(B, " ");

	    switch (qa->query[i].operand)
		{
		    case QUERY_WORD:
			break;
		    case QUERY_SUB:
			bprintf(B, "-");
			break;
		    case QUERY_PHRASE:
			break;
		    case QUERY_SUBPHRASE:
			bprintf(B, "-");
			break;
		    case QUERY_FILETYPE:
			bprintf(B, "filetype:");
			break;
		    case QUERY_LANGUAGE:
			bprintf(B, "language:");
			break;
		    case QUERY_COLLECTION:
			bprintf(B, "collection:");
			break;
		    case QUERY_DATE:
			bprintf(B, "date:");
			break;
		    case QUERY_STATUS:
			bprintf(B, "status:");
			break;
		    case QUERY_OR:
			bprintf(B, "| ");
			break;
		    case QUERY_SORT:
			bprintf(B, "sort:");
			break;
		    case QUERY_GROUP:
			bprintf(B, "group:");
			break;
		    case QUERY_ATTRIBUTE:
			bprintf(B, "attribute:");
			break;
		}

	    if (qa->query[i].n > 1 || qa->query[i].operand == QUERY_PHRASE
		|| qa->query[i].operand == QUERY_GROUP
		|| qa->query[i].operand == QUERY_ATTRIBUTE) {
		    if (escape)
			    bprintf(B, "&quot;");
		    else
			    bprintf(B, "\"");
	    }

	    for (j=0; j<qa->query[i].n; j++)
		{
		    char buf[2048];

		    if (j>0)
			{
			    if (qa->query[i].operand == QUERY_ATTRIBUTE) bprintf(B, "=");
			    else bprintf(B, " ");
			}
		    bprintf(B, "%s", escape ? xml_escape_uri(qa->query[i].s[j], buf, sizeof(buf)) : qa->query[i].s[j]);
		}

	    if (qa->query[i].n > 1 || qa->query[i].operand == QUERY_PHRASE
		|| qa->query[i].operand == QUERY_GROUP
		|| qa->query[i].operand == QUERY_ATTRIBUTE) {
		    if (escape)
			    bprintf(B, "&quot;");
		    else
			    bprintf(B, "\"");
	    }

	}

    return !all_gone;
}


void sprint_expanded_query( char *s, int n, query_array *qa )
{
    int		i, j, k;
    int		pos = 0;

    for (i=0; i<qa->n; i++)
	{
	    if (i>0) pos+= snprintf(s+pos, n - pos, " ");

	    switch (qa->query[i].operand)
		{
		    case QUERY_WORD:
			break;
		    case QUERY_SUB:
			pos+= snprintf(s+pos, n - pos, "-");
			break;
		    case QUERY_PHRASE:
			break;
		    case QUERY_SUBPHRASE:
			pos+= snprintf(s+pos, n - pos, "-");
			break;
		    case QUERY_FILETYPE:
			pos+= snprintf(s+pos, n - pos, "filetype:");
			break;
		    case QUERY_LANGUAGE:
			pos+= snprintf(s+pos, n - pos, "language:");
			break;
		    case QUERY_COLLECTION:
			pos+= snprintf(s+pos, n - pos, "collection:");
			break;
		    case QUERY_DATE:
			pos+= snprintf(s+pos, n - pos, "date:");
			break;
		    case QUERY_STATUS:
			pos+= snprintf(s+pos, n - pos, "status:");
			break;
		    case QUERY_OR:
			pos+= snprintf(s+pos, n - pos, "| ");
			break;
		    case QUERY_SORT:
			pos+= snprintf(s+pos, n - pos, "sort:");
			break;
		    case QUERY_GROUP:
			pos+= snprintf(s+pos, n - pos, "group:");
			break;
		    case QUERY_ATTRIBUTE:
			pos+= snprintf(s+pos, n - pos, "attribute:");
			break;
		}

	    if (qa->query[i].n > 1 || qa->query[i].operand == QUERY_PHRASE
		|| qa->query[i].operand == QUERY_GROUP
		|| qa->query[i].operand == QUERY_ATTRIBUTE) pos+= snprintf(s+pos, n - pos, "\"");

	    for (j=0; j<qa->query[i].n; j++)
		{
		    if (j>0) pos+= snprintf(s+pos, n - pos, " ");
		    pos+= snprintf(s+pos, n - pos, "%s", qa->query[i].s[j]);
		}

	    if (qa->query[i].n > 1 || qa->query[i].operand == QUERY_PHRASE
		|| qa->query[i].operand == QUERY_GROUP
		|| qa->query[i].operand == QUERY_ATTRIBUTE) pos+= snprintf(s+pos, n - pos, "\"");

	    if (qa->query[i].alt != NULL)
		{
		    pos+= snprintf(s+pos, n - pos, "(");
		    for (j=0; j<qa->query[i].alt_n; j++)
			{
			    if (j>0) pos+= snprintf(s+pos, n - pos, "|");
			    if (qa->query[i].alt[j].n > 1) pos+= snprintf(s+pos, n - pos, "\"");

			    for (k=0; k<qa->query[i].alt[j].n; k++)
				{
				    if (k>0) pos+= snprintf(s+pos, n - pos, " ");
				    pos+= snprintf(s+pos, n - pos, "%s", qa->query[i].alt[j].s[k]);
				}

			    if (qa->query[i].alt[j].n > 1) pos+= snprintf(s+pos, n - pos, "\"");
			}
		    pos+= snprintf(s+pos, n - pos, ")");
		}
	}

    if (pos < n) s[pos] = '\0';
    else s[n-1] = '\0';
}


void sprint_query_array( char *s, int n, query_array *qa )
{
    int		i, j, k;
    int		pos = 0;

    for (i=0; i<qa->n; i++)
	{
	    pos+= snprintf(s+pos, n - pos, "(%c):", qa->query[i].operand);

	    for (j=0; j<qa->query[i].n; j++)
		{
		    pos+= snprintf(s+pos, n - pos, " [%s]", qa->query[i].s[j]);
		}

	    if (qa->query[i].alt != NULL)
		{
		    pos+= snprintf(s+pos, n - pos, "alt:(");
		    for (j=0; j<qa->query[i].alt_n; j++)
			{
			    if (j>0) pos+= snprintf(s+pos, n - pos, "|");
			    if (qa->query[i].alt[j].n > 1) pos+= snprintf(s+pos, n - pos, "\"");

			    for (k=0; k<qa->query[i].alt[j].n; k++)
				{
				    if (k>0) pos+= snprintf(s+pos, n - pos, " ");
				    pos+= snprintf(s+pos, n - pos, "%s", qa->query[i].alt[j].s[k]);
				}

			    if (qa->query[i].alt[j].n > 1) pos+= snprintf(s+pos, n - pos, "\"");
			}
		    pos+= snprintf(s+pos, n - pos, ")");
		}

	    pos+= snprintf(s+pos, n - pos, "\n");
	}

    if (pos < n) s[pos] = '\0';
    else s[n-1] = '\0';
}
