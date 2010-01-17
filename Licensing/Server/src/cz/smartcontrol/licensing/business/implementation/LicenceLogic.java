/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.implementation;

import cz.smartcontrol.licensing.business.BadNumberException;
import cz.smartcontrol.licensing.business.LicenceNotFoundException;
import cz.smartcontrol.licensing.business.TooManyActivationsException;
import cz.smartcontrol.licensing.business.facade.LicenceFacade;
import cz.smartcontrol.licensing.business.facade.NumberFacade;
import cz.smartcontrol.licensing.business.implementation.number.Activation;
import cz.smartcontrol.licensing.business.implementation.number.Registration;
import java.util.Calendar;
import java.util.Date;

/**
 *
 * @author Martin
 */
public class LicenceLogic implements LicenceFacade {
    
    private NumberFacade numberLogic;
    
    public void setNumberLogic( NumberFacade numberLogic )
    {
        this.numberLogic = numberLogic;
    }

    public Date getFirstIssuedLicenceTime() throws LicenceNotFoundException
    {
        return Calendar.getInstance().getTime();
    }
    
    public String activate( String registrationNumber ) throws BadNumberException, LicenceNotFoundException, TooManyActivationsException
    {
        Registration registration = numberLogic.decodeRegistration( registrationNumber );
        Activation activation = new Activation();

        activation.setPId( registration.getPId());
        activation.setMId( registration.getMId());
        activation.setGOrd( registration.getGOrd());
        
        return numberLogic.encodeActivation( activation );
    }

}
