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
import javax.persistence.OneToMany;
import javax.persistence.Table;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.persistence.Version;

@Entity
@Table(name="app_manufacturer")
public class Manufacturer implements VersionedDomainObject {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "company_id")
    private Long companyId;
    
    @Column(name = "name", nullable=false)
    private String name;
    
    @Column(name = "street", nullable=false)
    private String street;
    
    @Column(name = "city", nullable=false)
    private String city;
    
    @Column(name = "postcode", length=10, nullable=false)
    private String postcode;
    
    @Column(name = "country", length=50, nullable=false)
    private String country;
    
    @Column(name = "ico", length=10, nullable=false)
    private String ico;
    
    @Column(name = "dic", length=10, nullable=false)
    private String dic;
    
    @Column(name="active", nullable=false)
    private Boolean active;
    
    @Column(name="created", nullable=false)
    @Temporal(TemporalType.TIMESTAMP)
    private Date created;
    
    @OneToMany(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="company")
    @org.hibernate.annotations.Cascade (value=org.hibernate.annotations.CascadeType.DELETE_ORPHAN)
    private List<Operator> operators;
    
    @OneToMany(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="company")
    @org.hibernate.annotations.Cascade (value=org.hibernate.annotations.CascadeType.DELETE_ORPHAN)
    private List<Product> products;
    
    @Column(name="version", nullable=false)
    @Version
    private Long version;
    
    public Serializable getPrimaryKey() {
        return getCompanyId();
    }

    public Long getCompanyId() {
        return companyId;
    }

    public void setCompanyId(Long companyId) {
        this.companyId = companyId;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion(Long version) {
        this.version = version;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getStreet() {
        return street;
    }

    public void setStreet(String street) {
        this.street = street;
    }

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }

    public String getPostcode() {
        return postcode;
    }

    public void setPostcode(String postcode) {
        this.postcode = postcode;
    }

    public String getCountry() {
        return country;
    }

    public void setCountry(String country) {
        this.country = country;
    }

    public String getIco() {
        return ico;
    }

    public void setIco(String ico) {
        this.ico = ico;
    }

    public String getDic() {
        return dic;
    }

    public void setDic(String dic) {
        this.dic = dic;
    }
    
    public List<Operator> getOperators() {
        return operators;
    }

    public void setOperators(List<Operator> operators) {
        this.operators = operators;
    }

    public List<Product> getProducts() {
        return products;
    }

    public void setProducts( List<Product> products ) {
        this.products = products;
    }

    public Date getCreated() {
        return created;
    }

    public void setCreated(Date created) {
        this.created = created;
    }

    public Boolean getActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

}
