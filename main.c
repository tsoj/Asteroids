#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>
int wi, he;
char *f;
long gt()
{
    struct timeval t;
    gettimeofday(&t, 0);
    return t.tv_usec / 1000 + t.tv_sec * 1000;
}
char *i2s(d, b, z, i)
{
    for (z = 0, i = 1; d / i; ++z)
        i *= b;
    z = d ? z : 1;
    char *s = malloc(z + 1);
    for (i = z - 1; i + 1; --i)
        s[i] = 48 + d % b, d /= b;
    s[z] = 0;
    return s;
}
void cl(i)
{
    for (i = 0; i < he * wi; ++i)
        f[i] = ' ';
}
void pr()
{
    f[he * wi] = 0;
    fprintf(stderr, "\033[0;0H%s", f);
}
void spr(int cl, int rw, int w, int h, char sp[h][w])
{
    for (int r = 0; r < h; ++r)
        for (int c = 0; c < w; ++c)
            sp[r][c] && (rw + r) < he && (cl + c) < wi && (rw + r) >= 0 && (cl + c) >= 0
                ? f[(rw + r) * wi + cl + c] = sp[r][c]
                : 0;
}
void str(int cl, int rw, char *st)
{
    for (int i = 0; st[i]; ++i)
        f[rw * wi + cl + i] = st[i];
}
int col(int cl1, int rw1, int w1, int h1, char sp1[h1][w1], int cl2, int rw2, int w2, int h2, char sp2[h2][w2])
{
    for (int r1 = 0; !((cl1 - cl2 > w2 && cl1 >= cl2) || (cl2 - cl1 > w1 && cl2 >= cl1) ||
                       (rw1 - rw2 > h2 && rw1 >= rw2) || (rw2 - rw1 > h1 && rw2 >= rw1)) &&
                     r1 < h1;
         ++r1)
        for (int c1 = 0; c1 < w1; ++c1)
            for (int r2 = 0; sp1[r1][c1] && r2 < h2; ++r2)
                for (int c2 = 0; c2 < w2; ++c2)
                    if (sp2[r2][c2] && cl1 + c1 == cl2 + c2 && rw1 + r1 == rw2 + r2)
                        return 0;
    return 0;
}
typedef struct
{
    float x, y;
} Vc2;
main()
{
    struct termios t, o;
    memset(&t, 0, sizeof t);
    tcgetattr(0, &t);
    o = t;
    t.c_lflag &= ~ICANON & ~ECHO;
    t.c_cc[VMIN] = 0;
    t.c_cc[VTIME] = 0;
    tcsetattr(0, TCSANOW, &t);
    struct winsize w;
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
    he = w.ws_row;
    wi = w.ws_col;
    f = malloc((he * wi + 1) * sizeof *f);
    srand(time(0));
    int rnnng = 1, M_A = wi * he / 250, M_S = wi * he / 50, now = gt(), last, sc = 0, be = 0, at[M_A], hit;
    Vc2 pp = {wi / 2, he / 2}, pv = {0, 0}, bp, ap[M_A], av[M_A], sp[M_S];
    float bv = -20, sv = 15, d;
    char i, el, er, *s, ss[4][6] = {"\0\0/\\\0\0", "\0/__\\\0", "\0\0^^\0\0", "\0\0**\0\0"},
                        as[5][3][6] = {{"\0\0oOo\0", "\0OO0Oo", "\0o00o\0"},
                                       {"\0o0Oo\0", "oO000o", "\0oO0o\0"},
                                       {"\0o0Oo\0", "oO0OOo", "\0oOo\0\0"},
                                       {"\0oo0\0\0", "o00OOo", "\0oOOOo"},
                                       {"\0o0Oo\0", "oO00Oo", "\0o0o\0\0"}},
                        bu[1][1] = {"@"};
    for (int i = 0; i < M_A; ++i)
        ap[i].x = rand() % wi, ap[i].y = rand() % he - he, av[i].x = -8 + rand() % 15, av[i].y = 10 + rand() % 5,
        at[i] = rand() % 5;
    for (int i = 0; i < M_S; ++i)
        sp[i].x = rand() % wi, sp[i].y = rand() % he;
    while (rnnng)
    {
        last = now;
        now = gt();
        d = (now - last) / 1000.0;
        cl();
        i = 0;
        read(0, &i, 1);
        i == 'a' ? pv.x = -20, pv.y = 0 : i == 'd' ? pv.x = 20, pv.y = 0 : i == 'w' ? pv.y = -15,
                   pv.x = 0 : i == 's' ? pv.y = 15, pv.x = 0 : i == ' ' ? bp.x = pp.x + 2, bp.y = pp.y,
                   be = 1
    : i == 'q' ? rnnng = 0
               : 0;
        pp.x += d * pv.x;
        pp.y += d * pv.y;
        pp.x = pp.x < 0 ? 0 : pp.x >= wi - 6 ? wi - 6 : pp.x;
        pp.y = pp.y < 0 ? 0 : pp.y >= he - 4 ? he - 4 : pp.y;
        be ? bp.y += d * bv, spr(bp.x, bp.y, 1, 1, bu), bp.y <= 0 ? be = 0 : 0 : 0;
        for (int i = 0; i < M_S; ++i)
            sp[i].y += d * sv, sp[i].y >= he ? sp[i].y = 0, sp[i].x = rand() % wi : 0, str(sp[i].x, sp[i].y, ".");
        for (int i = 0; i < M_A; ++i)
            ap[i].x += d * av[i].x, ap[i].y += d * av[i].y,
                hit = 0, be && col(bp.x, bp.y, 1, 1, bu, ap[i].x, ap[i].y, 6, 3, as[at[i]]) ? hit = 1, sc += 10,
                be = 0 : 0, ap[i].x < 0 - 6 || ap[i].x >= wi + 6 || ap[i].y >= he + 3 || hit ? sc += 1, ap[i].y = 0,
                ap[i].x = rand() % wi, av[i].x = -8 + rand() % 15, av[i].y = 10 + rand() % 5, at[i] = rand() % 5 : 0,
                spr(ap[i].x, ap[i].y, 6, 3, as[at[i]]),
                col(pp.x, pp.y, 6, 4, ss, ap[i].x, ap[i].y, 6, 3, as[at[i]]) ? rnnng = 0 : 0;
        s = i2s(sc, 10);
        str(0, 0, "SCORE");
        str(6, 0, s);
        free(s);
        el = 33 + (rand() % (47 - 33));
        er = 33 + (rand() % (47 - 33));
        ss[3][2] = el;
        ss[3][3] = er;
        spr(pp.x, pp.y, 6, 4, ss);
        pr();
        struct timespec req = {0, 16000000};
        nanosleep(&req, 0);
    }
    free(f);
    tcsetattr(0, TCSADRAIN, &o);
    printf("FINAL SCORE %i\n", sc);
}
