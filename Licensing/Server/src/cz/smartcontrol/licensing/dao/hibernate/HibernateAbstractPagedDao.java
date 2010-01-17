/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.dao.hibernate;

import cz.smartcontrol.licensing.domain.model.DomainObject;
import cz.smartcontrol.query.AppliedFilter;
import cz.smartcontrol.query.Filter;
import cz.smartcontrol.query.Pager;
import cz.smartcontrol.query.Result;
import java.util.List;
import org.hibernate.Query;
import org.hibernate.ScrollableResults;

/**
 *
 * @author Martin
 */
public class HibernateAbstractPagedDao extends HibernateAbstractDataAccess {

    public DomainObject findFirst(boolean lazy, String[] fetches, Pager pager, Filter filter) {

        Pager findPager = new Pager();
        findPager.setCount(1);
        findPager.setDaoOrderBy( pager.getDaoOrderBy());

        Result result = find( lazy, fetches, findPager, filter );
        return (DomainObject)result.getData().get(0);
    }
    
    public Result find( boolean lazy, String[] fetches, Pager pager, Filter filter) {
        
        // prepare working buffer
        StringBuffer queryBuffer = new StringBuffer();
        queryBuffer.append( getBasicQuery());
        
        // apply fetches
        if( !lazy ) {
            for( String fetch : fetches ) {
                queryBuffer.append( " left outer join fetch " );
                queryBuffer.append( fetch );
            }
        }

        // do filtering
        AppliedFilter appliedFilter = null;
        if( filter != null ) {
            appliedFilter = applyFilter( filter );
        }
        if( appliedFilter != null ) {
            queryBuffer.append( " " );
            queryBuffer.append( appliedFilter.getWhereClause());
        }

        // do sorting
        if( pager != null ) {
            String[] orderBy = pager.getDaoOrderBy();
            if( orderBy != null && orderBy.length > 0 ) {
                queryBuffer.append( " order by ");

                int highIndex = orderBy.length-1;
                for( int i=0; i<=highIndex; i++) {
                    queryBuffer.append( orderBy[i] );
                    if( i < highIndex ) {
                        queryBuffer.append( ", " );
                    }
                }
            }
        }

        // create query itself
        String queryString = queryBuffer.toString();
        Query query = getSession( false ).createQuery( queryString );
        if( appliedFilter != null ) {
            query.setProperties( appliedFilter.getValues());
        }

        // apply paging
        boolean pagingApplied = false;
        if( pager != null && pager.getDaoPage() != null && pager.getPageSize() != null ) {
            pagingApplied = true;
            query.setFirstResult( pager.getDaoPage()*pager.getPageSize() );
            query.setMaxResults( pager.getPageSize() );
        }

        // do query
        List queryResult = query.list();
        // take a chance to initialize lazy references
        resolveReferences( lazy, fetches, queryResult );
        // make export data if needed
        List data = toExport( queryResult );

        // if pager is used count of items must be get too
        if( pagingApplied ) {
            pager.setCount( getCountOfQuery( appliedFilter ));
        }

        // prepare result
        Result result = new Result( data, pager, filter );
        // and deliver it
        return result;
    }

    protected String getBasicQuery() { // callback, TODO: should be abstract after checking of functionality
        return null;
    }

    protected AppliedFilter applyFilter(Filter filter) { // callback
        return null;
    }
    
    protected List toExport( List daoData ) { // callback
        return daoData;
    }
    
    protected void resolveReferences(boolean lazy, String[] fetches, List daoData) { // callback, allows (explicitely) fetching lazy references
    }

    private int getCountOfQuery( AppliedFilter appliedFilter ) {

        String queryString = getBasicQuery();
        int fromPos = queryString.indexOf( "from " );
        if( fromPos > 0 ) {
            queryString = queryString.substring( fromPos );
        }
        queryString = "select count(*) " + queryString;
        if( appliedFilter != null ) {
            queryString = queryString + " " + appliedFilter.getWhereClause();
        }

        Query query = getSession( false ).createQuery( queryString );
        if( appliedFilter != null ) {
            query.setProperties( appliedFilter.getValues());
        }
        List countResult = query.list();
        
        return countResult.indexOf(0);
    }

}
