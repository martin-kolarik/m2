package cz.smartcontrol.licensing.dao.hibernate;

import cz.smartcontrol.licensing.dao.facade.AbstractDao;
import cz.smartcontrol.licensing.domain.model.DomainObject;
import java.io.Serializable;
import java.util.List;
import org.springframework.orm.hibernate3.support.HibernateDaoSupport;

/**
 *
 * @author phrncarek
 */
public abstract class HibernateAbstractDataAccess extends HibernateDaoSupport
        implements AbstractDao {

    public Serializable create(DomainObject domainObject) {
        return getHibernateTemplate().save(domainObject);
    }

    public DomainObject update(DomainObject domainObject) {
        return (DomainObject)getHibernateTemplate().merge(domainObject);
    }
    
    public DomainObject findByPK(Class entityClass, Serializable pk) {
        return (DomainObject)getHibernateTemplate().get(entityClass, pk);
    }

    public List find(String queryString) {
        return getHibernateTemplate().find(queryString);
    }

    public List find(String queryString, Object value) {
        return getHibernateTemplate().find(queryString, value);
    }

    public List find(String queryString, Object [] values) {
        return getHibernateTemplate().find(queryString, values);
    }

    public void delete(DomainObject domainObject) {
        getHibernateTemplate().delete(domainObject);
    }
    
    public void evict(DomainObject domainObject) {
        getHibernateTemplate().evict(domainObject);
    }
    
}
