package cz.smartcontrol.licensing.domain;

import cz.smartcontrol.licensing.domain.model.VersionedDomainObject;
import java.io.Serializable;
import java.math.BigDecimal;
import java.util.Date;
import java.util.List;
import javax.persistence.CascadeType;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.FetchType;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.OneToMany;
import javax.persistence.Table;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.persistence.Version;

/**
 *
 * @author slovak
 */
@Entity
@Table(name="app_dealer")
public class Dealer implements VersionedDomainObject {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "customer_id")
    private Long customerId;
    
    @Column(name="company", nullable=true)
    private String company;
    
    @Column(name="discount")
    private BigDecimal discount;
    
    @OneToMany(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="dealer")
    @org.hibernate.annotations.Cascade (value=org.hibernate.annotations.CascadeType.DELETE_ORPHAN)
    private List<Customer> customers;
    
    @Column(name="created", nullable=false)
    @Temporal(TemporalType.TIMESTAMP)
    private Date created;
    
    @Column(name="version", nullable=false)
    @Version
    private Long version;
    
    public Serializable getPrimaryKey() {
        return getCustomerId();
    }

    public Long getCustomerId() {
        return customerId;
    }

    public void setCustomerId( Long customerId ) {
        this.customerId = customerId;
    }

    public String getCompany() {
        return company;
    }

    public void setCompany( String company ) {
        this.company = company;
    }

    public BigDecimal getDiscount() {
        return discount;
    }

    public void setDiscount( BigDecimal discount ) {
        this.discount = discount;
    }

    public List<Customer> getCustomers() {
        return customers;
    }

    public void setCustomers( List<Customer> customers ) {
        this.customers = customers;
    }

    public Date getCreated() {
        return created;
    }

    public void setCreated( Date created ) {
        this.created = created;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion( Long version ) {
        this.version = version;
    }

}
