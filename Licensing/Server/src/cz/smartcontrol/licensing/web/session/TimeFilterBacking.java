package cz.smartcontrol.licensing.web.session;

import cz.smartcontrol.licensing.business.facade.LicenceFacade;
import cz.smartcontrol.licensing.web.tools.ExportTools;
import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import javax.servlet.http.HttpSession;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.ui.Model;

/**
 *
 * @author strzinek
 */
public class TimeFilterBacking  {
    
    public static final String NAME_YEAR_LIST = "yearList";
    public static final String NAME_MONTH_LIST = "monthList";
    public static final String NAME_WEEK_LIST = "weekList";

    private static final String NAME_SELF = "timeFilterBacking";
    
    private List<String> yearList;
    private List<String> monthList;
    private List<String> weekList;
    
    public static TimeFilterBacking getInstance( HttpSession session, LicenceFacade licenceLogic ) throws Exception {
        
        TimeFilterBacking timeFilter = (TimeFilterBacking)session.getAttribute( NAME_SELF );
        if( timeFilter == null ) {
            timeFilter = new TimeFilterBacking( licenceLogic );
            session.setAttribute( NAME_SELF, timeFilter );
        }
        return timeFilter;
    }
    
    public static Calendar getTimeFilterCalendar() {

        return Calendar.getInstance( LocaleContextHolder.getLocale());
    }

    private TimeFilterBacking( LicenceFacade licenceLogic ) throws Exception {
        
        Calendar stopper = getTimeFilterCalendar();
        stopper.setTime( licenceLogic.getFirstIssuedLicenceTime() );

        // year list
        Calendar time = getTimeFilterCalendar();
        time.set( Calendar.DAY_OF_YEAR, 1 );
        stopper.add( Calendar.YEAR, -1 ); // round down
        yearList = new ArrayList<String>();
        DateFormat formatter = ExportTools.getYearFormatter();
        while( time.after( stopper )) {
            yearList.add( formatter.format( time.getTime()));
            time.add( Calendar.YEAR, -1 );
        }
        stopper.add( Calendar.YEAR, 1 ); // get back

        // month list
        time = getTimeFilterCalendar();
        time.set( Calendar.DAY_OF_MONTH, 1 );
        stopper.add( Calendar.MONTH, -1 ); // round down
        monthList = new ArrayList<String>();
        formatter = ExportTools.getMonthFormatter();
        while( time.after( stopper )) {
            monthList.add( formatter.format( time.getTime()));
            time.add( Calendar.MONTH, -1 );
        }
        stopper.add( Calendar.MONTH, 1 ); // get back

        // week list
        time = getTimeFilterCalendar();
        time.set( Calendar.DAY_OF_WEEK, time.getFirstDayOfWeek());
        stopper.add( Calendar.WEEK_OF_YEAR, -1 ); // round down
        weekList = new ArrayList<String>();
        formatter = ExportTools.getWeekFormatter(); 
        while( time.after( stopper )) {
            String weekString = formatter.format( time.getTime());
            if( time.get( Calendar.WEEK_OF_YEAR ) == 1 && time.get( Calendar.MONTH ) == Calendar.DECEMBER ) { // special case, when first week of year starts in previous year, correct year
                int year = time.get( Calendar.YEAR );
                String yearString = Integer.toString( year );
                String nextYearString = Integer.toString( year+1 );
                weekString = weekString.replace( yearString, nextYearString );
            }
            weekList.add( weekString );
            time.add( Calendar.WEEK_OF_YEAR, -1 );
        }
    }
    
    public void bindToModel( Model model ) {
        
        model.addAttribute( NAME_YEAR_LIST, yearList );
        model.addAttribute( NAME_MONTH_LIST, monthList );
        model.addAttribute( NAME_WEEK_LIST, weekList );
    }
}
