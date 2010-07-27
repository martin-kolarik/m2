package cz.smartcontrol.licensing.web.bind;

import cz.smartcontrol.licensing.business.facade.ManufacturerFacade;
import cz.smartcontrol.licensing.domain.Manufacturer;
import java.beans.PropertyEditorSupport;

/**
 *
 * @author mk
 */
public class ManufacturerPropertyEditor extends PropertyEditorSupport {
    
    private ManufacturerFacade manufacturerLogic;
    
    public ManufacturerPropertyEditor( ManufacturerFacade manufacturerLogic )
    {
        this.manufacturerLogic = manufacturerLogic;
    }
    
    @Override
    public void setAsText(String text) throws IllegalArgumentException
    {
        for( Manufacturer manufacturer : manufacturerLogic.getManufacturers())
        {
            if( String.valueOf(manufacturer.getCompanyId()).equals(text))
            {
                setValue(manufacturer);
            }
        }
    }

    @Override
    public String getAsText()
    {
        if( getValue() == null ) {
            return null;
        }
        return String.valueOf( ((Manufacturer)getValue()).getCompanyId() );
    }

}
