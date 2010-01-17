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
@Table(name="app_licence")
public class Licence implements VersionedDomainObject {
    
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "licence_id")
    private Long licenceId;
    
    @ManyToOne(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="customer")
    private Customer customer;
    
    @ManyToOne(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="product")
    private Product product;
    
    @OneToOne(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="preactivation", nullable=true)
    private Activation preActivation;
    
    @OneToMany(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="activation")
    @org.hibernate.annotations.Cascade (value=org.hibernate.annotations.CascadeType.DELETE_ORPHAN)
    private List<Activation> activations;
    
    @Column(name="trial", nullable=false)
    private Boolean trial;
    
    @Column(name="educational", nullable=false)
    private Boolean educational;
    
    @Column(name="upgrade", nullable=false)
    private Boolean upgrade;
    
    @Column(name="upgrade_from", length=64, nullable=false)
    private Licence upgradedFrom;
    
    @Column(name="named", nullable=false)
    private Boolean named;
    
    @Column(name="name", nullable=true)
    private String name;
    
    @Column(name="created", nullable=false)
    @Temporal(TemporalType.TIMESTAMP)
    private Date created;
    
    @Column(name="version", nullable=false)
    @Version
    private Long version;
    
    public Serializable getPrimaryKey() {
        return getLicenceId();
    }

    public Long getLicenceId() {
        return licenceId;
    }

    public void setLicenceId( Long licenceId ) {
        this.licenceId = licenceId;
    }

    public Customer getCustomer() {
        return customer;
    }

    public void setCustomer( Customer customer ) {
        this.customer = customer;
    }

    public Product getProduct() {
        return product;
    }

    public void setProduct( Product product ) {
        this.product = product;
    }

    public Activation getPreActivation() {
        return preActivation;
    }

    public void setPreActivation( Activation preActivation ) {
        this.preActivation = preActivation;
    }

    public List<Activation> getActivations() {
        return activations;
    }

    public void setActivations( List<Activation> activations ) {
        this.activations = activations;
    }

    public Boolean getTrial() {
        return trial;
    }

    public void setTrial( Boolean trial ) {
        this.trial = trial;
    }

    public Boolean getEducational() {
        return educational;
    }

    public void setEducational( Boolean educational ) {
        this.educational = educational;
    }

    public Boolean getUpgrade() {
        return upgrade;
    }

    public void setUpgrade( Boolean upgrade ) {
        this.upgrade = upgrade;
    }

    public Licence getUpgradedFrom() {
        return upgradedFrom;
    }

    public void setUpgradedFrom( Licence upgradedFrom ) {
        this.upgradedFrom = upgradedFrom;
    }

    public Boolean getNamed() {
        return named;
    }

    public void setNamed( Boolean named ) {
        this.named = named;
    }

    public String getName() {
        return name;
    }

    public void setName( String name ) {
        this.name = name;
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
