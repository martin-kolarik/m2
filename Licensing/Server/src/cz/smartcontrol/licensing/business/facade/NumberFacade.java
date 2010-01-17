/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.facade;

import cz.smartcontrol.licensing.business.BadNumberException;
import cz.smartcontrol.licensing.business.implementation.number.Activation;
import cz.smartcontrol.licensing.business.implementation.number.Registration;

/**
 *
 * @author Martin
 */
public interface NumberFacade {

    Activation decodeActivation( String activationNumber ) throws BadNumberException;
    String encodeActivation( Activation activation ) throws BadNumberException;

    Registration decodeRegistration( String registrationNumber ) throws BadNumberException;
    String encodeRegistration( Registration registration ) throws BadNumberException;

}
