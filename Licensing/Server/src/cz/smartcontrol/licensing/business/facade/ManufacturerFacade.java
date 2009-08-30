/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.facade;

import cz.smartcontrol.licensing.domain.Manufacturer;
import cz.smartcontrol.query.Filter;
import cz.smartcontrol.query.Pager;
import cz.smartcontrol.query.Result;
import java.util.List;

/**
 *
 * @author Martin
 */
public interface ManufacturerFacade {
    
    public Manufacturer getManufacturer( long id );

    public List<Manufacturer> getManufacturers();

    public Result getManufacturers( Filter filter, Pager pager );
    
    public void addManufacturer( Manufacturer manufacturer, String password );

    public void updateManufacturer( Manufacturer manufacturer, String password );

}
