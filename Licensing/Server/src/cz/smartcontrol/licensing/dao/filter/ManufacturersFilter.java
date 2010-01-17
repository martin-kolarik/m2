/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.dao.filter;

import cz.smartcontrol.query.Filter;

/**
 *
 * @author Martin
 */
public class ManufacturersFilter implements Filter {
    
    private String filterWords;

    private String category;
    
    public String getFilterWords() {
        return filterWords;
    }

    public void setFilterWords( String filterWords ) {
        this.filterWords = filterWords;
    }

}
