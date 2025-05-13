//Supported specifiers: %%, %c, %s, %d, %x, %o, %b.

#include <stdio.h>
#include <time.h>

#include "my_printf.h"

int main()
{
    double standart_printf_time = 0.0;
    double my_printf_time = 0.0;
    clock_t start = clock();
    clock_t end = clock();
    for ( int i = 0; i < ITERATIONS; i++ )
    {
        start = clock();
        printf("specifier %%c: %c \n\
specifier %%s: %s \n\
specifier %%d: %d \n\
specifier %%x: %x \n\
specifier %%o: %o \n\
specifier %%b: %b \n",

                'X',"Hello world!", 42, 42, 42, 42 );
        end = clock();
        standart_printf_time += (double)(end - start) / CLOCKS_PER_SEC;

printf ("\n\n\n");
        start = clock();

        my_printf("specifier %%c: %c\n\
specifier %%s: %s \n\
specifier %%d: %d \n\
specifier %%x: %x \n\
specifier %%o: %o \n\
specifier %%b: %b \n",

                'X',"Hello world!", 42, 42, 42, 42 );
        end = clock();

        my_printf_time += (double)(end - start) / CLOCKS_PER_SEC;

    }
    printf ( "Standart printf: %f seconds\n", my_printf_time / ITERATIONS );
    printf ( "my_printf: %f seconds\n", standart_printf_time / ITERATIONS);

    my_printf("%d %s %x %d%%%c%b\n" , -1 , "love" , 3802 , 100 , 33 , 30 );

    return 0;
}
