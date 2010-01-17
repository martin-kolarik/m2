/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.implementation;

import cz.smartcontrol.licensing.business.BadNumberException;
import cz.smartcontrol.licensing.business.facade.NumberFacade;
import cz.smartcontrol.licensing.business.implementation.number.Activation;
import cz.smartcontrol.licensing.business.implementation.number.Number;
import cz.smartcontrol.licensing.business.implementation.number.Registration;
import java.util.ArrayList;

/**
 *
 * @author Martin
 */
public class NumberLogic implements NumberFacade {
    
    private static char[] c5ToCh = { 
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 
        '2', '3', '4', '5', '6', '7', '8', '9',
        'R', 'S', 'T', 'U', 'W', 'X', 'Y', 'Z',
        'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P'
    };
    
    private static byte[] cChTo5 = {
        30, 24,  8,  9, 10, 11, 12, 13, 14, 15, // numbers
        -1, -1, -1, -1, -1, -1, -1, // spare
         0,  1,  2,  3,  4,  5,  6,  7, // A..H
        24, 25, 26, 27, 28, 29, 30, 31, // I..P
        30, 16, 17, 18, 19, 19, 20, 21, 22, 23 // Q, R..U,V..Z
    };
    
    public Activation decodeActivation( String activationNumber ) throws BadNumberException {
        Activation activation = new Activation();
        decodeNumber( activationNumber, activation );
        return activation;
    }
    
    public String encodeActivation( Activation activation ) throws BadNumberException {
        return encodeNumber( activation );
    }
    
    public Registration decodeRegistration( String registrationNumber ) throws BadNumberException {
        Registration registration = new Registration();
        decodeNumber( registrationNumber, registration );
        return registration;
    }
    
    public String encodeRegistration( Registration registration ) throws BadNumberException {
        return encodeNumber( registration );
    }
    
    private static void decodeNumber( String input, Number target ) throws BadNumberException {
        byte[] unscrambled = unscramble( input, target.getPrefix(), target.getSeparator() );
        if( unscrambled == null || unscrambled.length == 0 )
        {
            throw new BadNumberException();
        }
        target.setOA( unscrambled );
    }
    
    private static String encodeNumber( Number target ) throws BadNumberException {
        byte[] unscrambled = target.getOA();
        return scramble( unscrambled, target.getPrefix(), target.getSeparator() );
    }
    
    private static String scramble( byte[] numberData, String prefix, char separator ) throws BadNumberException {
        if( numberData.length > 140 )
        {
            throw new BadNumberException();
        }

        byte[] rebitted = rebit( numberData, 8, 5 );
        int l = rebitted.length;
        if( l < 5 )
        {
            throw new BadNumberException();
        }

	// mask and apply last uncomplete byte to checksum
        for( int i = 0; i <= 2; i++ )
        {
            rebitted[i] = (byte)(rebitted[i] ^ rebitted[l-1]);
        }
        for( int i = 3; i <= l-2; i++ )
        {
            rebitted[l-1] = (byte)(rebitted[l-1] ^ rebitted[i]);
        }

        return prefix.concat( byte2String( rebitted, 5, separator, rebitted[0] ));
    }
    
    private static byte[] unscramble( String numberData, String prefix, char separator ) throws BadNumberException {
        numberData = numberData.toUpperCase();
        
        int separatorIndex = numberData.indexOf( separator );
        if( separatorIndex != -1 )
        {
            String numberPrefix = numberData.substring( separatorIndex );
            if( !prefix.equals( numberPrefix ))
            {
                throw new BadNumberException();
            }
        }

        String number = numberData.substring( separatorIndex+1, -1 );
	int l = number.length();
        if( l < 5 || l > 250 )
        {
            throw new BadNumberException();
        }
        
        byte[] byteData = string2Byte( number, 5, separator );
        if( byteData == null )
        {
            throw new BadNumberException();
        }
        
	// unmask and unapply last uncomplete byte to checksum
        for( int i = 3; i <= l-2; i++ )
        {
            byteData[l-1] = (byte)(byteData[l-1] ^ byteData[i]);
        }
        for( int i = 0; i <= 2; i++ )
        {
            byteData[i] = (byte)(byteData[i] ^ byteData[l-1]);
        }
	
	return rebit( byteData, 5, 8 );
    }

    private static byte[] rebit( byte[] input, int srcbits, int destbits ) {

        int sl = input.length;
        int dl;
        if( srcbits > destbits ) {
            dl = ( sl * srcbits + srcbits - 1 ) / destbits;
        } else {
            dl = sl * srcbits / destbits;
        }

        byte[] output = new byte[dl];
        for( int c = 0; c < dl; c++ ) {
            output[c] = 0;
        }
        
	int c;
	int di = 0, dy = 0;
	int si = 0, sy = 0;
        while( sy < sl ) {
            if( srcbits - si < destbits - di ) {
                c = srcbits - si;
            } else {
                c = destbits - di;
            }
            if( si > di ) {
                output[dy] = (byte)( output[dy] | ( input[sy] >> ( si - di )));
            } else {
                output[dy] = (byte)( output[dy] | ( input[sy] << ( di - si )));
            }
            si += c;
            if( si == srcbits ) {
                sy++;
                si = 0;
            }
            di += c;
            if( di == destbits ) {
                dy++;
                di = 0;
            }
        }

        int mask = 1 << destbits - 1;
	int last = mask;
	for( int i = 0; i < dl; i++ ) {
            output[i] = (byte)(output[i] & mask);
            last = last ^ output[i];
        }
	if( sl < dl ) { // some bits are not filled
            output[dy] = (byte)( output[dy] | ( last << di ) & mask );
        }
      
        return output;
    }
    
    private static String byte2String( byte[] input, int groupWidth, char separator, byte control ) {
        
	char[] v5ToCh = new char[c5ToCh.length];
        System.arraycopy( c5ToCh, 0, v5ToCh, 0, c5ToCh.length );
        String output = "";

        for( int i = 0; i < input.length; i++ ) {
            if( !"".equals( separator ) && i > 0 && i % groupWidth == 0 ) {
                output = output + separator;
            }
            
            byte c = control;
            for( int rotCount = 0; rotCount < i; rotCount++ ) {
                if(( 1 & c ) == 0 ) {
                    c = (byte)( c / 2 );
                } else {
                    c = (byte)( c / 2 + 128 );
                }
            }

            if(( 1 & c ) != 0 ) {
		v5ToCh[19] = 'U';
            } else {
                v5ToCh[19] = 'V';
            }
            if(( 2 & c ) != 0 ) {
		v5ToCh[24] = 'I';
            } else {
                v5ToCh[24] = '1';
            }
            if(( 4 & c ) != 0 ) {
		v5ToCh[30] = 'O';
            } else if(( 8 & c ) != 0 ) {
                v5ToCh[30] = 'Q';
            } else {
                v5ToCh[30] = '0';
            }

            output = output + v5ToCh[ input[i] ];
        }

        for( int i = 0; i < groupWidth - 1 - (input.length-1) % groupWidth - 1; i++ ) {
            output = output + 'X';
        }
        return output;
    }
    
    private static byte[] string2Byte( String input, int groupWidth, char separator ) {
        
	int h = input.length() - 1;
        int j = 0;
	int s = groupWidth;
        ArrayList<Byte> output = new ArrayList<Byte>();

        for( int i = 0; i <= h; i++ ) {
            char in = input.charAt( i );
            
            if( in >= '0' && in <= '9')
            {
                output.add( new Byte( cChTo5[in-'0'] ));
                j++;
            }
            else if( in >= 'a' && in <= 'z' )
            {
                output.add( new Byte( cChTo5[in-'a'+'A'-'0'] ));
            }
            else if( in >= 'A' && in <= 'Z' )
            {
                output.add( new Byte( cChTo5[in-'0'] ));
            }
            else
            {
               if( i != s ) {
                   return null;
               } else if( in != separator ) {
                   return null;
               } else if( j == 0 && j % groupWidth > 0 ) {
                   return null;
               } // here proper positioned separator is detected
               s = s + groupWidth + 1;
            }
        }

        if( j % groupWidth > 0 ) {
	    return null;
        } else {
            byte[] out = new byte[output.size()];
            for( int i = 0; i < out.length; i++ ) {
                out[i] = output.get(i).byteValue();
            }
            return out;
        }
    }  
}
