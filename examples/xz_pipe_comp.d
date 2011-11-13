/*
 * xz_pipe_comp.c
 * A simple example of pipe-only xz compressor implementation.
 * version: 2010-07-12 - by Daniel Mealha Cabrita
 * Ported to D by Johannes Pfau
 * Not copyrighted -- provided to the public domain.
 *
 * Compiling:
 * Link with liblzma
 * $ dmd -L-llzmad xz_pipe_comp.d -ofxz_pipe_comp
 *
 * Usage example:
 * $ cat some_file | ./xz_pipe_comp > some_file.xz
 */

import std.stdio;
import deimos.lzma;

/* COMPRESSION SETTINGS */

/* analogous to xz CLI options: -0 to -9 */
enum COMPRESSION_LEVEL = 6;

/* boolean setting, analogous to xz CLI option: -e */
enum COMPRESSION_EXTREME = true;

/* see: /usr/include/lzma/check.h LZMA_CHECK_* */
enum INTEGRITY_CHECK = lzma_check.LZMA_CHECK_CRC64;


/* read/write buffer sizes */
enum IN_BUF_MAX   = 4096;
enum OUT_BUF_MAX  = 4096;

/* error codes */
enum RET
{
    OK                =   0,
    ERROR_INIT        =   1,
    ERROR_INPUT       =   2,
    ERROR_OUTPUT      =   3,
    ERROR_COMPRESSION =   4
}

/* note: in_file and out_file must be open already */
RET xz_compress (File in_file, File out_file)
{
    uint preset = COMPRESSION_LEVEL | (COMPRESSION_EXTREME ? LZMA_PRESET_EXTREME : 0);
    lzma_check check = INTEGRITY_CHECK;
    lzma_stream strm = lzma_stream.init; /* alloc and init lzma_stream struct */
    ubyte[IN_BUF_MAX] in_buf;
    ubyte[OUT_BUF_MAX] out_buf;
    size_t in_len;    /* length of useful data in in_buf */
    size_t out_len;    /* length of useful data in out_buf */
    bool in_finished = false;
    bool out_finished = false;
    lzma_action action;
    lzma_ret ret_xz;
    RET ret;

    ret = RET.OK;

    /* initialize xz encoder */
    ret_xz = lzma_easy_encoder (&strm, preset, check);
    if (ret_xz != lzma_ret.LZMA_OK)
    {
        stderr.writefln("lzma_easy_encoder error: %s", ret_xz);
        return RET.ERROR_INIT;
    }

    while ((! in_finished) && (! out_finished))
    {
        /* read incoming data */
        auto read = in_file.rawRead(in_buf[]);

        if (read.length == 0)
        {
            in_finished = true;
        }

        strm.next_in = read.ptr;
        strm.avail_in = read.length;

        /* if no more data from in_buf, flushes the
           internal xz buffers and closes the xz data
           with LZMA_FINISH */
        action = in_finished ? lzma_action.LZMA_FINISH : lzma_action.LZMA_RUN;

        /* loop until there's no pending compressed output */
        do
        {
            /* out_buf is clean at this point */
            strm.next_out = out_buf.ptr;
            strm.avail_out = out_buf.length;

            /* compress data */
            ret_xz = lzma_code (&strm, action);

            if ((ret_xz != lzma_ret.LZMA_OK) && (ret_xz != lzma_ret.LZMA_STREAM_END))
            {
                stderr.writefln("lzma_code error: %s", ret_xz);
                out_finished = true;
                ret = RET.ERROR_COMPRESSION;
            }
            else
            {
                /* write compressed data */
                out_len = out_buf.length - strm.avail_out;
                out_file.rawWrite(out_buf[0 .. out_len]);
            }
        }
        while (strm.avail_out == 0);
    }

    lzma_end(&strm);
    return ret;
}

int main()
{
    RET ret;

    ret = xz_compress (stdin, stdout);
    return cast(int)ret;
}
