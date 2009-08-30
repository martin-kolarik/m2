/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.implementation.support;

/**
 *
 * @author Martin
 */
public class Hash40 {

    private byte[] data = new byte[5];
    
    public Hash40()
    {
        for( int i = 0; i < data.length; i++ )
        {
            data[0] = 0;
        }
    }
    
    public int length()
    {
        return data.length;
    }
    
    public byte[] get()
    {
        return data;
    }
    
    public void set( byte[] value )
    {
        if( value.length != data.length )
        {
            return;
        }
        data = value;
    }
    
    public void set( Hash40 value )
    {
        data = value.data;
    }

}
