/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.implementation.support;

/**
 *
 * @author Martin
 */
public class Key {
    
    private byte[] data = new byte[32];
    
    public int length()
    {
        return data.length;
    }
    
    public Key( byte[] source )
    {
        set( source );
    }
    
    public void set( byte[] source )
    {
        int min = source.length;
        if( min > data.length )
        {
            min = data.length;
        }
        for( int i = 0; i < min; i++ )
        {
            data[i] = source[i];
        }
        for( int i = min; i < data.length; i++ )
        {
            data[i] = 0;
        }
    }
    
    public byte[] get()
    {
        return data;
    }

    public byte at( int index )
    {
        if( index >= 0 && index < data.length )
        {
            return data[index];
        }
        else
        {
            return 0;
        }
    }
    
    public void set( int index, byte value )
    {
        if( index >= 0 && index < data.length )
        {
            data[index] = value;
        }
    }

}
