/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cz.smartcontrol.query;

import java.util.List;

/**
 *
 * @author Martin
 */
public class Result {

    private Pager pager;
    
    private Filter filterUsed;
    
    private List data;
    
    public Result( List data, Pager pager, Filter filterUsed ) {
        this.data = data;
        this.pager = pager;
        this.filterUsed = filterUsed;
    }
    
    public boolean getHasData() {
        return data != null && data.size() > 0;
    }

    public Pager getPager() {
        return pager;
    }

    public Filter getFilterUsed() {
        return filterUsed;
    }

    public List getData() {
        return data;
    }

}
