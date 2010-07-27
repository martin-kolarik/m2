/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.services.implementation;

import cz.smartcontrol.licensing.business.BadNumberException;
import cz.smartcontrol.licensing.business.LicenceNotFoundException;
import cz.smartcontrol.licensing.business.TooManyActivationsException;
import cz.smartcontrol.licensing.business.facade.LicenceFacade;
import cz.smartcontrol.licensing.services.BadNumberServiceException;
import cz.smartcontrol.licensing.services.LicenceNotFoundServiceException;
import cz.smartcontrol.licensing.services.TooManyActivationsServiceException;
import cz.smartcontrol.licensing.services.facade.ClientService;

/**
 *
 * @author Martin
 */
public class ClientServiceReceptor implements ClientService {

    private LicenceFacade licenceLogic;
    
    public void setLicenceLogic( LicenceFacade licenceLogic )
    {
        this.licenceLogic = licenceLogic;
    }
    
    public String activate( String registrationNumber ) throws BadNumberServiceException, LicenceNotFoundServiceException, TooManyActivationsServiceException
    {
        try
        {
            return licenceLogic.activate( registrationNumber );
        }
        catch( BadNumberException e )
        {
            throw new BadNumberServiceException();
        }
        catch( LicenceNotFoundException e )
        {
            throw new LicenceNotFoundServiceException();
        }
        catch( TooManyActivationsException e )
        {
            throw new TooManyActivationsServiceException();
        }
    }

}
