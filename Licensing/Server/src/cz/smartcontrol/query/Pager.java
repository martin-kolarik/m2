/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.query;

import java.util.HashMap;
import java.util.Map;

/**
 *
 * @author Martin
 */
public class Pager {
    
    private int page; // set by user
    private int pageSize; // set by user
    private int count; // set by Dao
    
    private String[] webKeys; // set by setupWebRequestOrdering
    private String[] domainObjectPropertyNames; // set by setupWebRequestOrdering
    
    private Map<String, Boolean> sortable = new HashMap<String, Boolean>(); // set internally
    private Map<String, Boolean> displayOrderBy = new HashMap<String, Boolean>(); // set internally
    private String[] daoOrderBy; // set internally or by setDaoOrderBy
    
    public Integer getDaoPage() {
        return page;
    }

    public void setDaoPage( Integer page ) {
        this.page = page;
    }

    public void setDisplayPage( Integer page ) {
        this.page = page-1;
    }

    public Integer getDisplayPage() {
        return page+1;
    }

    public Integer getPageSize() {
        return pageSize;
    }

    public void setPageSize( Integer pageSize ) {
        this.pageSize = pageSize;
    }
    
    public Integer getPages() {
        if( pageSize == 0 || count == 0 ) {
            return 1;
        }
        int pages = count / pageSize;
        if( pages * pageSize < count ) {
            return pages+1;
        } else {
            return pages;
        }
    }
    
    public Boolean getIsOnStart() {
        return page == 0;
    }

    public Boolean getIsOnEnd() {
        return page == getPages()-1;
    }

    public Integer getCount() {
        return count;
    }
    
    public Integer getDisplayFrom() {
        return page * pageSize + 1;
    }

    public Integer getDisplayTo() {
        if( getDisplayFrom() + pageSize < getCount()) { // if last page is not full, displayed value must not be greater than count
            return getDisplayFrom() + pageSize - 1;
        } else {
            return getCount();
        }
    }

    public void setCount( Integer count ) {
        this.count = count;
    }

    public void setDaoOrderBy( String[] daoOrderBy ) {
        this.daoOrderBy = daoOrderBy;
        this.displayOrderBy = null;
    }
    
    public String[] getDaoOrderBy() {
        return daoOrderBy;
    }

    public Map<String, Boolean> getDisplayOrderedBy() {
        return displayOrderBy;
    }
    
    public Map<String, Boolean> getSortable() {
        return sortable;
    }

    public void setupWebRequestOrdering( String[] webKeys, String[] domainObjectPropertyNames ) {
        this.webKeys = webKeys;
        if( domainObjectPropertyNames == null ) {
            this.domainObjectPropertyNames = webKeys;
        } else {
            this.domainObjectPropertyNames = domainObjectPropertyNames;
        }
        sortable.clear();
        for( int i = 0; i < webKeys.length; i++ ) {
            if( "".equals( domainObjectPropertyNames[i] )) {
                sortable.put( webKeys[i], Boolean.FALSE );
            } else {
                sortable.put( webKeys[i], Boolean.TRUE );
            }
        }
    }
    
    public void updateByWebRequest( String stringPageSizeIncrement, String stringPageOffset, String webOrderBy ) {
        
        // validate input
        Integer pageSizeIncrement = null;
        try {
            if( stringPageSizeIncrement != null ) {
                pageSizeIncrement = Integer.parseInt( stringPageSizeIncrement );
            }
        } catch( NumberFormatException e ) {
            // return;
        }
        Integer pageOffset = null;
        try {
            if( stringPageOffset != null ) {
                pageOffset = Integer.parseInt( stringPageOffset );
            }
        } catch( NumberFormatException e ) {
            return;
        }

        // apply page size
        if( pageSizeIncrement != null ) {
            int newPageSize = pageSize + pageSizeIncrement;
            if( newPageSize < 10 ) {
                newPageSize = 10;
            }
            pageSize = newPageSize;

            // adjust view if page count is smaller when previous one
            int pages = getPages();
            if( page > pages ) {
                page = pages;
            }
        }
        
        // apply page offset
        if( pageOffset != null && pageOffset > 0 && pageOffset <= getPages()) {
            setDisplayPage( pageOffset );
        }
        
        // apply ordering
        if( webKeys != null && webOrderBy != null ) {
            String[] ordering = webOrderBy.split( "\\." );
            if( ordering.length != 2 ) {
                ordering = new String[]{webOrderBy, null};
            }

            for( int i = 0; i < webKeys.length; i++ ) {
                if( webKeys[i].equals( ordering[0] )) {
                    if( "desc".equals( ordering[1] )) {
                        daoOrderBy = new String[]{ domainObjectPropertyNames[i] + " desc" };
                        displayOrderBy.clear();
                        displayOrderBy.put( webKeys[i], Boolean.FALSE );
                    } else {
                        daoOrderBy = new String[]{ domainObjectPropertyNames[i] };
                        displayOrderBy.clear();
                        displayOrderBy.put( webKeys[i], Boolean.TRUE );
                    }
                    break;
                }
            }
        }
    }

}
