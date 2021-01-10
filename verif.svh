`ifndef __VERIF_H__
`define __VERIF_H__


//
// logger

`define info(str, mod=m_mod)                        \
    verif::g_logger.log(verif::logger::INFO, str, mod)

`define warn(str, mod=m_mod)                        \
    verif::g_logger.log(verif::logger::WARN, str, mod)

`define  err(str, mod=m_mod)                        \
    verif::g_logger.log(verif::logger::ERR,  str, mod)

`define trig                                        \
    verif::g_logger.m_trig


//
// plugin

`define plug(arg=1)                                  \
    verif::g_plugins.main()


//
// rand number

`define urand(min=m_min, max=m_max)                 \
    $urandom_range(min, max)

`define ratio(max=100)                              \
    $urandom_range(0,   max)

`define rands(sig, w=)                              \
    do                                              \
        std::randomize(sig) w;                      \
    while (0)


//
// queue

`define find(typ, obj, que, cond)                   \
    do begin                                        \
        typ arr[$] = que.find_first() with (cond);  \
        if (arr.size())                             \
            obj = arr.pop_front();                  \
    end while (0)


//
// factory

`define register(nam)                               \
    static verif::wrapper_base m_wrapper = verif::wrapper#(nam)::set(`"nam`")

`define spawn(nam, obj)                             \
    do                                              \
        if (!$cast(obj, verif::g_spawner.get(nam))) \
           `err($sformatf("failed to cast %0s",     \
                           nam));                   \
    while (0)


//
// database

`define set(typ, key, val)                          \
    verif::database#(typ)::set(key, val)

`define get(typ, key, val)                          \
    verif::database#(typ)::get(key, val)


//
// sequence

`define start(typ, nam, fun=put)                    \
    do begin                                        \
        typ tr;                                     \
       `spawn(nam, tr);                             \
        fun(tr);                                    \
    end while (0)


//
// misc

`ifdef  IUS
`define deposit(nam, val)                           \
    $deposit(nam, val)

`else
`define deposit(nam, val)                           \
    nam = val
`endif

`define waitn(num=1)                                \
    repeat ((num))                                  \
        @(posedge `clk)

`define waits(sig)                                  \
    do                                              \
        @(posedge `clk);                            \
    while (~(sig))

`define waitt(sig, max, str, mod=m_mod)             \
    do                                              \
        for (int i = 0; 1; i++) begin               \
            if (sig)                                \
                break;                              \
            if (i >= max)                           \
               `err(str, mod);                      \
            @(posedge `clk);                        \
        end                                         \
    while (0)

`endif