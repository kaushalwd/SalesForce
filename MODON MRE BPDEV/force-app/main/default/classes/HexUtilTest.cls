/**********************************************************************************************************************
* Name               : HexUtilTest
* Description        : Test coverage for HexUtil — hex<->int conversion helpers and the CRC-32 (zlib/PKZIP
*                       polynomial) implementation used by Zippex.
* Created By         : (assistant)
* --------------------------------------------------------------------------------------------------------------------
* All CRC-32 expected values below were independently verified with Python's zlib.crc32() (the standard reference
* implementation for this exact polynomial), not hand-calculated — including the well-known industry test vector
* CRC-32("123456789") = 0xCBF43926, used across many CRC-32 implementations specifically to catch table/polynomial
* errors.
**********************************************************************************************************************/
@isTest
private class HexUtilTest {

    // ======================================================================================
    // hexToIntLE — little-endian hex string -> Integer
    // ======================================================================================

    @isTest
    static void testHexToIntLE_singleByte(){
        // 0xFF as a single byte -> 255
        System.assertEquals(255, HexUtil.hexToIntLE('ff'));
    }

    @isTest
    static void testHexToIntLE_fourByteLittleEndian(){
        // Bytes [01,00,00,00] little-endian -> 1
        System.assertEquals(1, HexUtil.hexToIntLE('01000000'));
    }

    @isTest
    static void testHexToIntLE_fourByteLittleEndian_largerValue(){
        // Bytes [ff,00,00,00] little-endian -> 255 (same as single-byte case, just padded)
        System.assertEquals(255, HexUtil.hexToIntLE('ff000000'));

        // Bytes [00,01,00,00] little-endian -> 256 (0x0100)
        System.assertEquals(256, HexUtil.hexToIntLE('00010000'));
    }

    @isTest
    static void testHexToIntLE_zero(){
        System.assertEquals(0, HexUtil.hexToIntLE('00000000'));
    }

    // ======================================================================================
    // intToHexLE — Integer -> little-endian hex string, padded to sizeInBytes
    // ======================================================================================

    @isTest
    static void testIntToHexLE_one_fourBytes(){
        System.assertEquals('01000000', HexUtil.intToHexLE(1, 4));
    }

    @isTest
    static void testIntToHexLE_255_oneByte(){
        System.assertEquals('ff', HexUtil.intToHexLE(255, 1));
    }

    @isTest
    static void testIntToHexLE_zero_twoBytes(){
        // decNumber == 0 never enters the while loop — output should be all padding.
        System.assertEquals('0000', HexUtil.intToHexLE(0, 2));
    }

    @isTest
    static void testIntToHexLE_256_twoBytes(){
        // 256 = 0x0100 -> little-endian bytes [00, 01]
        System.assertEquals('0001', HexUtil.intToHexLE(256, 2));
    }

    @isTest
    static void testHexConversion_roundTrip(){
        Integer original = 305419896; // 0x12345678
        String hex = HexUtil.intToHexLE(original, 4);
        Integer roundTripped = HexUtil.hexToIntLE(hex);
        System.assertEquals(original, roundTripped, 'intToHexLE/hexToIntLE should round-trip.');
    }

    // ======================================================================================
    // CRC32Table(Blob) — verified against Python's zlib.crc32() (reference implementation)
    // ======================================================================================

    @isTest
    static void testCRC32Table_blob_emptyInput_isZero(){
        System.assertEquals(0, HexUtil.CRC32Table(Blob.valueOf('')));
    }

    @isTest
    static void testCRC32Table_blob_standardTestVector(){
        // CRC-32("123456789") = 0xCBF43926 — the standard industry test vector for this exact
        // polynomial/table, used specifically to catch table or algorithm errors.
        Integer expected = -873187034; // 0xCBF43926 as a signed 32-bit Integer
        System.assertEquals(expected, HexUtil.CRC32Table(Blob.valueOf('123456789')));
    }

    @isTest
    static void testCRC32Table_blob_shortString(){
        // Verified independently via Python's zlib.crc32(b'AB').
        Integer expected = 812207111;
        System.assertEquals(expected, HexUtil.CRC32Table(Blob.valueOf('AB')));
    }

    // ======================================================================================
    // CRC32Table(String) — same algorithm, taking an already-hex-encoded byte string
    // ======================================================================================

    @isTest
    static void testCRC32Table_hexString_matchesBlobOverload(){
        // Hex encoding of "123456789" (ASCII) should give the identical CRC-32 result as the
        // Blob overload above — proves both overloads implement the same algorithm consistently.
        String hexOf123456789 = EncodingUtil.convertToHex(Blob.valueOf('123456789'));
        Integer expected = -873187034;
        System.assertEquals(expected, HexUtil.CRC32Table(hexOf123456789));
        System.assertEquals(HexUtil.CRC32Table(Blob.valueOf('123456789')), HexUtil.CRC32Table(hexOf123456789));
    }

    @isTest
    static void testCRC32Table_hexString_emptyInput_isZero(){
        System.assertEquals(0, HexUtil.CRC32Table(''));
    }
}