/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.facade;

import cz.smartcontrol.licensing.business.BadNumberException;
import cz.smartcontrol.licensing.business.LicenceNotFoundException;
import cz.smartcontrol.licensing.business.TooManyActivationsException;
import java.util.Date;

/**
 *
 * @author Martin
 */
public interface LicenceFacade {

    Date getFirstIssuedLicenceTime() throws LicenceNotFoundException;
    
    String activate( String registrationNumber ) throws BadNumberException, LicenceNotFoundException, TooManyActivationsException;

}
