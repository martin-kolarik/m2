/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

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
import javax.persistence.OneToOne;
import javax.persistence.Table;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.persistence.Version;

/**
 *
 * @author Martin
 */
@Entity
@Table(name="app_product")
public class Product implements VersionedDomainObject {
    
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "product_id")
    private Long productId;
    
    @Column(name="pid", nullable=false)
    private String productTextId;
    
    @ManyToOne(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="manufacturer")
    private Manufacturer manufacturer;

    @Column(name="uniquer", nullable=false)
    private UniquerType uniquer;
    
    @OneToMany(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="version")
    @org.hibernate.annotations.Cascade (value=org.hibernate.annotations.CascadeType.DELETE_ORPHAN)
    private List<ProductVersion> versions;
    
    @OneToMany(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="licence")
    @org.hibernate.annotations.Cascade (value=org.hibernate.annotations.CascadeType.DELETE_ORPHAN)
    private List<Licence> licences;
    
    @Column(name="released", nullable=true)
    @Temporal(TemporalType.TIMESTAMP)
    private Date released;
    
    @Column(name="abandoned", nullable=true)
    @Temporal(TemporalType.TIMESTAMP)
    private Date abandoned;
    
    @OneToOne(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name = "replaced_by", nullable = true)
    private Product replacedBy;
    
    @Column(name="supported", nullable=true)
    @Temporal(TemporalType.TIMESTAMP)
    private Date supported;
    
    @Column(name="created", nullable=false)
    @Temporal(TemporalType.TIMESTAMP)
    private Date created;
    
    @Column(name="version", nullable=false)
    @Version
    private Long version;

    public Serializable getPrimaryKey() {
        return getProductId();
    }

    public Long getProductId() {
        return productId;
    }

    public void setProductId( Long productId ) {
        this.productId = productId;
    }

    public String getProductTextId() {
        return productTextId;
    }

    public void setProductTextId( String productTextId ) {
        this.productTextId = productTextId;
    }

    public Manufacturer getManufacturer() {
        return manufacturer;
    }

    public void setManufacturer( Manufacturer manufacturer ) {
        this.manufacturer = manufacturer;
    }

    public UniquerType getUniquer() {
        return uniquer;
    }

    public void setUniquer( UniquerType uniquer ) {
        this.uniquer = uniquer;
    }

    public List<ProductVersion> getVersions() {
        return versions;
    }

    public void setVersions( List<ProductVersion> versions ) {
        this.versions = versions;
    }

    public List<Licence> getLicences() {
        return licences;
    }

    public void setLicences( List<Licence> licences ) {
        this.licences = licences;
    }

    public Date getReleased() {
        return released;
    }

    public void setReleased( Date released ) {
        this.released = released;
    }

    public Date getAbandoned() {
        return abandoned;
    }

    public void setAbandoned( Date abandoned ) {
        this.abandoned = abandoned;
    }

    public Product getReplacedBy() {
        return replacedBy;
    }

    public void setReplacedBy( Product replacedBy ) {
        this.replacedBy = replacedBy;
    }

    public Date getSupported() {
        return supported;
    }

    public void setSupported( Date supported ) {
        this.supported = supported;
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
