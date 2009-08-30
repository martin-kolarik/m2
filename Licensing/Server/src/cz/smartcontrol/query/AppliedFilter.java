/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.query;

import java.util.Map;

/**
 *
 * @author Martin
 */
public class AppliedFilter {
    
    private String whereClause;
    
    private Map<String, Object> values;
    
    public AppliedFilter( String whereClause, Map<String, Object> values ) {
        this.whereClause = whereClause;
        this.values = values;
    }

    public String getWhereClause() {
        return whereClause;
    }

    public Map<String, Object> getValues() {
        return values;
    }

}
