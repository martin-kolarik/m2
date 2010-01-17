/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.dao.filter;

import cz.smartcontrol.query.Filter;
import java.util.Date;

/**
 *
 * @author Martin
 */
public class TimeFilter implements Filter {

    private Date dateFrom;

    private Date dateTo;

    public Date getDateFrom() {
        return dateFrom;
    }

    public void setDateFrom( Date dateFrom ) {
        this.dateFrom = dateFrom;
    }

    public Date getDateTo() {
        return dateTo;
    }

    public void setDateTo( Date dateTo ) {
        this.dateTo = dateTo;
    }
    
}
