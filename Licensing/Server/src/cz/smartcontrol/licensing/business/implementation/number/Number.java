/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.implementation.number;

import cz.smartcontrol.licensing.business.implementation.support.Key;
import java.security.MessageDigest;

/**
 *
 * @author Martin
 */
public abstract class Number {
    
    protected static byte[] salt = {
        (byte)0xAB, 0x27, (byte)0x0E1, 0x56, (byte)0x0F5, 0x28, 0x45, (byte)0x0EF, (byte)0x0A5, 0x49, 0x6E, (byte)0x0B9, 0x7F, 0x39, 0x1C, (byte)0x0D1
    };
    
    public abstract char getSeparator();

    public abstract String getPrefix();

    public abstract void setOA( byte[] oa );
    
    public abstract byte[] getOA();
    
    protected static void permute( int permuteAbout, Key K, Key IV )
    {
        int evenPermute = permuteAbout & 0xff;
        int oddPermute = ( permuteAbout >> 8 ) & 0xff;

        for( int i = 0; i < K.length(); i++ )
        {
            if( i % 2 == 0 )
            {
                K.set(i, (byte)(K.at(i) ^ evenPermute) );
                IV.set(i, (byte)(IV.at(i) ^ evenPermute) );
            }
            else
            {
                K.set(i, (byte)(K.at(i) ^ oddPermute) );
                IV.set(i, (byte)(IV.at(i) ^ oddPermute) );
            }
        }

        try
        {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            K.set( digest.digest( K.get()) );
            IV.set( digest.digest( IV.get()) );
        }
        catch( Exception e )
        {
        }
    }
    
    protected static byte[] digestSalt( byte[] input, byte[] salt )
    {
        int min = salt.length;
        if( input.length < min )
        {
            min = input.length;
        }

        byte[] local = new byte[min];
        for( int i = 0; i < min; i++ )
        {
            local[i] = (byte)(input[i] ^ salt[i]);
        }
        
        try
        {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update( local );
            if( input.length > min )
            {
                local = new byte[input.length-min];
                System.arraycopy( input, min, local, 0, input.length-min );
            }
            digest.update( local );
            return digest.digest();
        }
        catch( Exception e )
        {
            return null;
        }
    }

}
