/**********************************************************************************************************************
* Name               : PuffTest
* Description        : Test coverage for Puff, the DEFLATE (RFC 1951) decompressor used by Zippex.
* Created By         : (assistant)
* --------------------------------------------------------------------------------------------------------------------
* IMPORTANT — HOW THESE TEST VECTORS WERE PRODUCED: hand-constructing a valid DEFLATE bitstream (correct Huffman
* codes, bit ordering, etc.) byte-by-byte is extremely error-prone. Instead, every compressed hex string below was
* generated with Python's zlib (compressobj(..., -15) for a raw, headerless/trailerless DEFLATE stream — exactly
* the format Puff expects) and round-trip verified with Python's own decompressor before being used here. That
* means these are REAL, independently-correct DEFLATE streams, not approximations:
*   - "AB" and "Hello World" at compression level 0 -> STORED blocks (BTYPE=00)
*   - "aaaa" and "abcabcabcabc" at compression level 9 -> FIXED Huffman blocks (BTYPE=01)
*   - the longer repeated-phrase text at compression level 9 -> a DYNAMIC Huffman block (BTYPE=10)
* Together these exercise stored(), fixed(), dynamic(), construct(), codes(), decode(), and bits() — i.e. every
* code path in Puff reachable through its one public entry point, inflate().
*
* Puff.inflate() itself contains an internal System.assertEquals(0, err) — if decompression fails for any reason,
* Puff throws that assertion itself, so a failing test here points at Puff (or a transcription error in the hex
* below), not at test-side logic.
*
* NOTE: Puff.inflate() returns a HEX-ENCODED string of the decompressed bytes (it's built by concatenating hex
* substrings internally), not the literal decoded text — so assertions compare against expected hex, with an
* extra EncodingUtil.convertFromHex(...).toString() step added where useful to also show the plain-text result.
**********************************************************************************************************************/
@isTest
private class PuffTest {

    @isTest
    static void testInflate_storedBlock_shortText(){
        // "AB" compressed at level 0 (forces a STORED block).
        String compressedHex = '010200fdff4142';
        String expectedHex   = '4142'; // hex for "AB"

        Puff p = new Puff(compressedHex, 7, 2);
        String result = p.inflate();

        System.assertEquals(expectedHex, result);
        System.assertEquals('AB', EncodingUtil.convertFromHex(result).toString());
    }

    @isTest
    static void testInflate_storedBlock_longerText(){
        // "Hello World" compressed at level 0 (STORED block).
        String compressedHex = '010b00f4ff48656c6c6f20576f726c64';
        String expectedHex   = '48656c6c6f20576f726c64'; // hex for "Hello World"

        Puff p = new Puff(compressedHex, 16, 11);
        String result = p.inflate();

        System.assertEquals(expectedHex, result);
        System.assertEquals('Hello World', EncodingUtil.convertFromHex(result).toString());
    }

    @isTest
    static void testInflate_fixedHuffmanBlock_repeatedChar(){
        // "aaaa" compressed at level 9 -> a FIXED Huffman block (BTYPE=01), using a
        // length/distance back-reference for the repeated 'a's.
        String compressedHex = '4b4c4c4c0400';
        String expectedHex   = '61616161'; // hex for "aaaa"

        Puff p = new Puff(compressedHex, 6, 4);
        String result = p.inflate();

        System.assertEquals(expectedHex, result);
        System.assertEquals('aaaa', EncodingUtil.convertFromHex(result).toString());
    }

    @isTest
    static void testInflate_fixedHuffmanBlock_repeatedPattern(){
        // "abcabcabcabc" compressed at level 9 -> FIXED Huffman with a longer back-reference.
        String compressedHex = '4b4c4a4e842100';
        String expectedHex   = '616263616263616263616263'; // hex for "abcabcabcabc"

        Puff p = new Puff(compressedHex, 7, 12);
        String result = p.inflate();

        System.assertEquals(expectedHex, result);
        System.assertEquals('abcabcabcabc', EncodingUtil.convertFromHex(result).toString());
    }

    @isTest
    static void testInflate_dynamicHuffmanBlock_longVariedText(){
        // A longer, varied 220-byte phrase compressed at level 9 — zlib chose a DYNAMIC
        // Huffman block (BTYPE=10) for this one (confirmed by inspecting the block-type bits
        // of the compressed output before using it here). This is the only vector that
        // exercises dynamic()/construct() with a real, non-fixed code table.
        String compressedHex = 'b5cbcb1582301046e1567e8fbaf3500325b8a081210c244a3232497855ef5884ebfbddce33961adc1bbdca9630ca8e578d9f0c5959512ccf741e18646ad0fd0d3fc95c3cd01bda42f118c3ca964e4e98c35245ed9df2039486df9a902532782f4aa8c904c37952728535e3d25e6ff7e60b';
        String expectedHex   = '54686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f672e2054686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f672e2054686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f672e205061636b206d7920626f782077697468206669766520646f7a656e206c6971756f72206a7567732c20616e64207468656e20736f6d6520657874726120756e6971756520636861726163746572732021402324252e';
        String expectedText  = 'The quick brown fox jumps over the lazy dog. '
                              + 'The quick brown fox jumps over the lazy dog. '
                              + 'The quick brown fox jumps over the lazy dog. '
                              + 'Pack my box with five dozen liquor jugs, and then some extra unique characters !@#$%.';

        Puff p = new Puff(compressedHex, 113, 220);
        String result = p.inflate();

        System.assertEquals(expectedHex, result);
        System.assertEquals(expectedText, EncodingUtil.convertFromHex(result).toString());
    }
}