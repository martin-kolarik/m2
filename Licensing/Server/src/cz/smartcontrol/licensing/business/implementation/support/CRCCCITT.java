/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.implementation.support;

/**
 *
 * @author Martin
 */
public class CRCCCITT {

    public static int crc( byte[] bytes )
    { 
        int crc = 0xFFFF;          // initial value
        int polynomial = 0x1021;   // 0001 0000 0010 0001  (0, 5, 12) 

        for (byte b : bytes) {
            for (int i = 0; i < 8; i++) {
                boolean bit = ((b   >> (7-i) & 1) == 1);
                boolean c15 = ((crc >> 15    & 1) == 1);
                crc <<= 1;
                if (c15 ^ bit) crc ^= polynomial;
             }
        }

        return crc & 0xffff;
    }

}
