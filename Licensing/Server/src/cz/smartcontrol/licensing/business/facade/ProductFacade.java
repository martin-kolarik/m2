/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.facade;

import cz.smartcontrol.query.Filter;
import cz.smartcontrol.query.Pager;
import cz.smartcontrol.query.Result;

/**
 *
 * @author Martin
 */
public interface ProductFacade {

    public Result getProducts( Filter filter, Pager pager );
    
}
