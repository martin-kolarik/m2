package cz.smartcontrol.licensing.web.commands;

import cz.smartcontrol.licensing.dao.filter.LicenceFilter;
import cz.smartcontrol.query.Result;
import java.text.ParseException;
import java.util.Calendar;
import java.util.List;
import org.springframework.context.i18n.LocaleContextHolder;

/**
 *
 * @author strzinek
 */
public class LicenceCommand extends AbstractTimeFilterCommand {

    private LicenceFilter filter = new LicenceFilter();
    
    private Result result;

    private List<String> selectedTickets;
    
    public LicenceCommand() {
        setRange( RANGE_MONTH );
        filter.setDateFrom( Calendar.getInstance( LocaleContextHolder.getLocale()).getTime() );
        filter.setDateTo( filter.getDateFrom());
    }

    public LicenceFilter getFilter() {
        return filter;
    }

    public Result getResult() {
        return result;
    }

    public void setResult( Result result ) {
        this.result = result;
    }

    public void setupFilter() throws ParseException {
        setupFilter( getFilter());
    }

    public List<String> getSelectedTickets() {
        return selectedTickets;
    }

    public void setSelectedTickets( List<String> ticketIds ) {
        this.selectedTickets = ticketIds;
    }

}
