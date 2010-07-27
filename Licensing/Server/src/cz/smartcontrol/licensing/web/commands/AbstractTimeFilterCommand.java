package cz.smartcontrol.licensing.web.commands;

import cz.smartcontrol.licensing.dao.filter.TimeFilter;
import cz.smartcontrol.licensing.web.session.TimeFilterBacking;
import cz.smartcontrol.licensing.web.tools.ExportTools;
import java.text.ParseException;
import java.util.Calendar;
import java.util.Date;

/**
 *
 * @author strzinek
 */
abstract public class AbstractTimeFilterCommand {
    
    public static final String RANGE_DAY = "D";
    public static final String RANGE_WEEK = "W";
    public static final String RANGE_MONTH = "M";
    public static final String RANGE_YEAR = "Y";

    private String range = RANGE_DAY;
    private String day;
    private String week;
    private String month;
    private String year;
    
    public AbstractTimeFilterCommand() {
        Calendar time = TimeFilterBacking.getTimeFilterCalendar();
        day = ExportTools.getDateFormatter().format( time.getTime());
        week = ExportTools.getWeekFormatter().format( time.getTime());
        month = ExportTools.getMonthFormatter().format( time.getTime());
        year = ExportTools.getYearFormatter().format( time.getTime());
    }
    
    public String getRange() {
        return range;
    }

    public void setRange( String range ) {
        this.range = range;
    }

    public String getDayString() {
        return this.day;
    }

    public void setDayString( String day ) {
        this.day = day;
    }

    public boolean validateDay() {

        try {
            ExportTools.getDateFormatter().parse( day );
        } catch( ParseException pe ) {
            return false;
        }
        return true;
    }

    public String getWeekString() {
        return this.week;
    }
    
    public void setWeekString( String week ) {
        this.week = week;
    }
    
    public boolean validateWeek() {

        try {
            ExportTools.getWeekFormatter().parse( week );
        } catch( ParseException pe ) {
            return false;
        }
        return true;
    }
    
    public String getMonthString() {
        return this.month;
    }
    
    public void setMonthString( String month ) {
        this.month = month;
    }
    
    public boolean validateMonth() {

        try {
            ExportTools.getMonthFormatter().parse( month );
        } catch( ParseException pe ) {
            return false;
        }
        return true;
    }
    
    public String getYearString() {
        return this.year;
    }
    
    public void setYearString( String year ) {
        this.year = year;
    }
    
    public boolean validateYear() {

        try {
            ExportTools.getYearFormatter().parse( year );
        } catch( ParseException pe ) {
            return false;
        }
        return true;
    }
    
    public void setupFilter( TimeFilter filter ) throws ParseException {

        Calendar calTo = TimeFilterBacking.getTimeFilterCalendar();
        Date dateFrom = calTo.getTime();
        
        if( RANGE_DAY.equals( getRange() )) {
            dateFrom = ExportTools.getDateFormatter().parse( day );
            calTo.setTime( dateFrom );
            calTo.add( Calendar.DAY_OF_YEAR, 1 );
        }
        else if( RANGE_WEEK.equals( getRange() )) {
            dateFrom = ExportTools.getWeekFormatter().parse( week );
            calTo.setTime( dateFrom );
            // there could be discrepancy with first week of year: week with number 1 can start in december, but
            // in TimeFilterBacking there is correction which displays this december week of previous year
            // as first week of current year. For backward conversion, which is done here, the year must be
            // rolled out backward for this case
            if( calTo.get( Calendar.WEEK_OF_YEAR ) == 1 && calTo.get( Calendar.MONTH ) == Calendar.DECEMBER ) {
                calTo.add( Calendar.YEAR, -1 );
                dateFrom = calTo.getTime();
            }
            calTo.add( Calendar.DAY_OF_YEAR, 7 );
        }
        else if( RANGE_MONTH.equals( getRange() )) {
            dateFrom = ExportTools.getMonthFormatter().parse( month );
            calTo.setTime( dateFrom );
            calTo.add( Calendar.MONTH, 1 );
        }
        else if( RANGE_YEAR.equals( getRange() )) {
            dateFrom = ExportTools.getYearFormatter().parse( year );
            calTo.setTime( dateFrom );
            calTo.add( Calendar.YEAR, 1 );
        }
        
        filter.setDateFrom( dateFrom );
        filter.setDateTo( calTo.getTime());
    }
    
    public String getCurrentDisplayPeriod() {

        if( RANGE_DAY.equals( getRange() )) {
            try {
                Date dateFrom = ExportTools.getDateFormatter().parse( day );
                return ExportTools.getFullDateFormatter().format( dateFrom );
            } catch( ParseException e ) {
                return ""; // in case of error there is no need to show period corectly
            }
        } else if( RANGE_WEEK.equals( getRange() )) {
            return week;
        } else if( RANGE_MONTH.equals( getRange() )) {
            return month;
        } else if( RANGE_YEAR.equals( getRange() )) {
            return year;
        }
        return "";
    }

}
