package cz.smartcontrol.licensing.web.commands;

import cz.smartcontrol.licensing.dao.filter.ManufacturersFilter;
import cz.smartcontrol.query.Result;
import java.text.ParseException;

/**
 *
 * @author strzinek
 */
public class ManufacturersCommand {

    private ManufacturersFilter filter = new ManufacturersFilter();
    
    private Result result;

    public ManufacturersFilter getFilter() {
        return filter;
    }

    public Result getResult() {
        return result;
    }

    public void setResult( Result result ) {
        this.result = result;
    }

    public String getFilterWords() {
        return getFilter().getFilterWords();
    }

    public void setFilterWords( String filterWords ) {
        getFilter().setFilterWords( filterWords );
    }
    
    public void setupFilter() throws ParseException {
        setupFilter( getFilter());
    }

    private void setupFilter( ManufacturersFilter filter ) throws ParseException {
        // now empty
    }

}
