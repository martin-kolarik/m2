/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cz.smartcontrol.licensing.web.commands;

import cz.smartcontrol.licensing.domain.Manufacturer;
import org.springframework.beans.BeanUtils;

/**
 *
 * @author Martin
 */
public class ManufacturerDetailCommand extends Manufacturer {

    private String newPassword = "";

    public ManufacturerDetailCommand() {
    }

    public ManufacturerDetailCommand( Manufacturer manufacturer ) {
        BeanUtils.copyProperties( manufacturer, this );
        newPassword = "";
    }

    public Manufacturer getController() {
        Manufacturer manufacturer = new Manufacturer();
        BeanUtils.copyProperties( this, manufacturer );
        return manufacturer;
    }

    public String getNewPassword() {
        return newPassword;
    }

    public void setNewPassword( String password ) {
        newPassword = password;
    }
}
