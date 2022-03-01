package verif;

`include "verif.svh"


//
// dpi

import "DPI-C" function string get_plusargs();

import "DPI-C" function string get_env(input string nam);
import "DPI-C" function void   set_env(input string nam, string val);


//
// plusargs

class plusargs;

    typedef string str_map [string];

    static str_map  m_all;
    static plusargs m_inst;

    static function plusargs get_inst();
        if (m_inst == null) begin
            while (1) begin
                string str = get_plusargs();

                if (str == "")
                    break;
                else if (str[0] == "+") begin
                    string sub = str.substr(1, str.len() - 1);
                    string key;
                    string val;
                    int    len;

                    if (sub == "")
                        continue;

                    // guard
                    len =  sub.len() - 1;
                    sub = {sub, "="};

                    foreach (sub[i])
                        if (sub[i] == "=") begin
                            key = sub.substr(0,     i - 1);
                            val = sub.substr(i + 1, len);
                            break;
                        end

                    m_all[key] = val;
                end
            end

            m_inst = new("");
        end

        return m_inst;
    endfunction

    str_map m_map;

    function new(input string str);
        int len = str.len();

        foreach (m_all[i]) begin
            string sub = i.substr(0, len - 1);

            if (str == sub)
                m_map[i.substr(len, i.len() - 1)] = m_all[i];
        end
    endfunction

    function str_map get_all();
        return m_map;
    endfunction

    function string get_str(input string key, string def = "__NONE__");
        return m_map.exists(key) ? m_map[key] : def;
    endfunction

    function bit get_bit(input string key);
        return m_map.exists(key) ? 1'b1       : 1'b0;
    endfunction

    function int get_int(input string key, int def = 0, int radix = 10);
        string val = get_str(key, "");
        int    ret;

        if (val == "")
            return def;

        case (radix)
             2: ret = val.atobin();
             8: ret = val.atooct();
            10: ret = val.atoi  ();
            16: ret = val.atohex();
        endcase

        return ret;
    endfunction

endclass

// global for simplicity
plusargs g_plusargs = plusargs::get_inst();


//
// logger

class logger;

    static const int DBG  = -1;
    static const int INFO =  0;
    static const int WARN =  1;
    static const int ERR  =  2;

    static logger m_inst;

    // singleton
    static function logger get_inst();
        if (m_inst == null)
            m_inst =  new();

        return m_inst;
    endfunction

    int m_log_lvl;
    int m_log_lvls [$];

    int m_num_dbg;
    int m_num_info;
    int m_num_warn;
    int m_num_err;

    int m_err_max;
    int m_err_dly;
    int m_trig;

    function new();
        plusargs args = new("err.");

        m_log_lvl  =  args.get_int("log", 2);

        m_num_dbg  =  0;
        m_num_info =  0;
        m_num_warn =  0;
        m_num_err  =  0;

        m_err_max  =  args.get_int("max", 1);
        m_err_dly  =  args.get_int("dly", 0);
        m_trig     = -1;
    endfunction

    function void log(input int ver, string str, string mod);
        case (ver)
            DBG:  begin
                $display("(%d) [%s] D: %s", $time(), mod, str);
                m_num_dbg++;
            end
            INFO: begin
                $display("(%d) [%s] I: %s", $time(), mod, str);
                m_num_info++;
            end
            WARN: begin
                $display("(%d) [%s] W: %s", $time(), mod, str);
                m_num_warn++;
            end
            ERR:  begin
                $display("(%d) [%s] E: %s", $time(), mod, str);
                m_num_err++;
            end
        endcase

        if (m_num_err >= m_err_max)
            m_trig = m_err_dly;
    endfunction

endclass

// global for simplicity
logger g_logger = logger::get_inst();


//
// factory

typedef class wrapper;
typedef class spawner;

// global for simplicity
spawner g_spawner = spawner::get_inst();


class object;

    string m_mod = $sformatf("%m");
    int    m_min = 0;
    int    m_max = 0;

endclass


class wrapper_base extends object;

    virtual function object get(input logic ran = 1'b0);
        return null;
    endfunction

endclass


class wrapper #(type T = object) extends wrapper_base;

    typedef wrapper #(T) type_t;

    static type_t m_inst;
    static string m_str;

    // singleton
    static function wrapper_base set(input string str);
        if (m_inst == null) begin
            m_inst =  new();
            m_str  =  str;

            g_spawner.set(str, m_inst);
        end

        return m_inst;
    endfunction

    // spawn support
    virtual function object get(input logic ran = 1'b0);
        T val = new();

        if (ran) begin
            if (!val.randomize())
               `warn($sformatf("randomization failed for %0s", m_str));
        end

        return val;
    endfunction

endclass


class spawner extends object;

    static spawner      m_inst;
    static wrapper_base m_map [string];

    // singleton
    static function spawner get_inst();
        if (m_inst == null)
            m_inst =  new();

        return m_inst;
    endfunction

    // register
    static function void set(input string str, wrapper_base wb);
        m_map[str] = wb;
    endfunction

    // spawn support
    function object get(input string str, logic ran = 1'b0);
        if (!m_map.exists(str)) begin
           `err($sformatf("%s is not registered", str), "spawner");
            return null;
        end

        return m_map[str].get(ran);
    endfunction

endclass


//
// plugin

class plugin extends object;

    virtual function void main();
    endfunction

endclass


class plugins extends object;

    static plugins m_inst;
    static string  m_arr [$];

    // singleton
    static function plugins get_inst();
        if (m_inst == null)
            m_inst =  new();

        return m_inst;
    endfunction

    function new();
        plusargs args         = new("with_");
        string   map [string] = args.get_all();

        foreach (map[i])
            m_arr.push_back(i);
    endfunction

    function main();
        foreach (m_arr[i]) begin
            plugin obj;

           `spawn(m_arr[i], obj);
            // hook
            obj.main();
        end
    endfunction

endclass

plugins g_plugins = plugins::get_inst();


//
// database

class database #(type T = int) extends object;

    static T m_map [string];

    static function void set(input string str, input T val);
        m_map[str] = val;
    endfunction

    static function void get(input string str, ref   T val);
        if (!m_map.exists(str))
           `err($sformatf("%s is not set by anyone", str), "database");
        else
            val = m_map[str];
    endfunction

endclass


//
// memory

class memory #(A = 32, D = 8) extends object;

    // mem core
    logic [D-1:0] m_map [logic [A-1:0]];
    logic [D-1:0] m_nil;

    function new(input string mod);
        m_mod = mod;
        m_nil = {D{1'b0}};
    endfunction

    function bit chk(input logic [A-1:0] a, int n = 1);
        for (int i = 0; i < n; i++)
            if (!m_map.exists(a))
                return 1'b0;

        return 1'b1;
    endfunction

    function void clr();
        m_map.delete();
    endfunction

    function bit [D*1-1:0] get_b(input logic [A-1:0] a, bit v = 1'b1);
        bit [D*1-1:0] d =  m_map.exists(a) ? m_map[a] : m_nil;
        if (v)
           `dbg($sformatf("[%x] -> %x", a, d));

        return d;
    endfunction

    function bit [D*2-1:0] get_h(input logic [A-1:0] a);
        bit [D*2-1:0] d = {get_b(a + {{A-1{1'b0}}, 1'd1}, 1'b0),
                           get_b(a + {{A-1{1'b0}}, 1'd0}, 1'b0)};
       `dbg($sformatf("[%x] -> %x", a, d));

        return d;
    endfunction

    function bit [D*4-1:0] get_w(input logic [A-1:0] a);
        bit [D*4-1:0] d = {get_b(a + {{A-2{1'b0}}, 2'd3}, 1'b0),
                           get_b(a + {{A-2{1'b0}}, 2'd2}, 1'b0),
                           get_b(a + {{A-2{1'b0}}, 2'd1}, 1'b0),
                           get_b(a + {{A-2{1'b0}}, 2'd0}, 1'b0)};
       `dbg($sformatf("[%x] -> %x", a, d));

        return d;
    endfunction

    function bit [D*8-1:0] get_d(input logic [A-1:0] a);
        bit [D*8-1:0] d = {get_b(a + {{A-3{1'b0}}, 3'd7}, 1'b0),
                           get_b(a + {{A-3{1'b0}}, 3'd6}, 1'b0),
                           get_b(a + {{A-3{1'b0}}, 3'd5}, 1'b0),
                           get_b(a + {{A-3{1'b0}}, 3'd4}, 1'b0),
                           get_b(a + {{A-3{1'b0}}, 3'd3}, 1'b0),
                           get_b(a + {{A-3{1'b0}}, 3'd2}, 1'b0),
                           get_b(a + {{A-3{1'b0}}, 3'd1}, 1'b0),
                           get_b(a + {{A-3{1'b0}}, 3'd0}, 1'b0)};
       `dbg($sformatf("[%x] -> %x", a, d));

        return d;
    endfunction

    function void set_b(input logic [A-1:0] a, logic [D*1-1:0] d);
       `dbg($sformatf("[%x] <- %x", a, d));

        m_map[a + {{A-1{1'b0}}, 1'd0}] = d;
    endfunction

    function void set_h(input logic [A-1:0] a, logic [D*2-1:0] d);
       `dbg($sformatf("[%x] <- %x", a, d));

        m_map[a + {{A-1{1'b0}}, 1'd1}] = d[D*1+:D];
        m_map[a + {{A-1{1'b0}}, 1'd0}] = d[D*0+:D];
    endfunction

    function void set_w(input logic [A-1:0] a, logic [D*4-1:0] d);
       `dbg($sformatf("[%x] <- %x", a, d));

        m_map[a + {{A-2{1'b0}}, 2'd3}] = d[D*3+:D];
        m_map[a + {{A-2{1'b0}}, 2'd2}] = d[D*2+:D];
        m_map[a + {{A-2{1'b0}}, 2'd1}] = d[D*1+:D];
        m_map[a + {{A-2{1'b0}}, 2'd0}] = d[D*0+:D];
    endfunction

    function void set_d(input logic [A-1:0] a, logic [D*8-1:0] d);
       `dbg($sformatf("[%x] <- %x", a, d));

        m_map[a + {{A-3{1'b0}}, 3'd7}] = d[D*7+:D];
        m_map[a + {{A-3{1'b0}}, 3'd6}] = d[D*6+:D];
        m_map[a + {{A-3{1'b0}}, 3'd5}] = d[D*5+:D];
        m_map[a + {{A-3{1'b0}}, 3'd4}] = d[D*4+:D];
        m_map[a + {{A-3{1'b0}}, 3'd3}] = d[D*3+:D];
        m_map[a + {{A-3{1'b0}}, 3'd2}] = d[D*2+:D];
        m_map[a + {{A-3{1'b0}}, 3'd1}] = d[D*1+:D];
        m_map[a + {{A-3{1'b0}}, 3'd0}] = d[D*0+:D];
    endfunction

endclass


endpackage