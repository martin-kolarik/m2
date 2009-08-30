/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.services.facade;

import cz.smartcontrol.licensing.services.BadNumberServiceException;
import cz.smartcontrol.licensing.services.LicenceNotFoundServiceException;
import cz.smartcontrol.licensing.services.TooManyActivationsServiceException;

/**
 *
 * @author Martin
 */
public interface ClientService {
    
    String activate( String registrationNumber ) throws BadNumberServiceException, LicenceNotFoundServiceException, TooManyActivationsServiceException;

}
