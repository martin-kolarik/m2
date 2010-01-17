package cz.smartcontrol.licensing.domain;

import cz.smartcontrol.licensing.domain.model.VersionedDomainObject;
import java.io.Serializable;
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
import javax.persistence.ManyToOne;
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
@Table(name="app_customer")
public class Customer implements VersionedDomainObject {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "customer_id")
    private Long customerId;
    
    @Column(name="company", nullable=true)
    private String company;
    
    @Column(name="first_name", nullable=false)
    private String firstName;
    
    @Column(name="last_name", nullable=false)
    private String lastName;
    
    @ManyToOne(fetch=FetchType.LAZY)
    @JoinColumn(name="dealer", nullable=true)
    private Dealer dealer;
    
    @OneToMany(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="customer")
    @org.hibernate.annotations.Cascade (value=org.hibernate.annotations.CascadeType.DELETE_ORPHAN)
    private List<Licence> licences;
    
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

    public String getFirstName() {
        return firstName;
    }

    public void setFirstName( String firstName ) {
        this.firstName = firstName;
    }

    public String getLastName() {
        return lastName;
    }

    public void setLastName( String lastName ) {
        this.lastName = lastName;
    }

    public Dealer getDealer() {
        return dealer;
    }

    public void setDealer( Dealer dealer ) {
        this.dealer = dealer;
    }

    public List<Licence> getLicences() {
        return licences;
    }

    public void setLicences( List<Licence> licences ) {
        this.licences = licences;
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
