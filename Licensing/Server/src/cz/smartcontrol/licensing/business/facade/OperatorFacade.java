/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.facade;

import cz.smartcontrol.licensing.business.BadLoginDataException;
import cz.smartcontrol.licensing.business.UnknownOperatorException;
import cz.smartcontrol.licensing.domain.Operator;

/**
 *
 * @author Martin
 */
public interface OperatorFacade {

    public Operator login( String username, String password ) throws UnknownOperatorException, BadLoginDataException;
    
}
