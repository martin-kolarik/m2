package cz.smartcontrol.licensing.dao.facade;

import cz.smartcontrol.query.Filter;
import cz.smartcontrol.query.Pager;
import cz.smartcontrol.query.Result;
import cz.smartcontrol.licensing.domain.model.DomainObject;
import java.io.Serializable;
import java.util.List;

/**
 *
 * @author Martin
 */
public interface AbstractDao {
    
    Serializable create(DomainObject domainObject);
    
    DomainObject update(DomainObject domainObject);
    
    void evict(DomainObject domainObject);

    void delete(DomainObject domainObject);
    
    /**
     * Return the persistent instance of the given entity class with the given identifier,
     * or null if not found.
     *
     * @return the persistent instance, or null if not found.
     */
    DomainObject findByPK(Class entityClass, Serializable pk);
    
    List find(String queryString);
    
    List find(String queryString, Object value);
    
    List find(String queryString, Object [] values);
    
    DomainObject findFirst(boolean lazy, String[] fetches, Pager pager, Filter filter); // calls getBasicQuery, applyFilter, resolveReferences, toExport
    
    Result find(boolean lazy, String[] fetches, Pager pager, Filter filter); // calls getBasicQuery, applyFilter, resolveReferences, toExport
    
}
