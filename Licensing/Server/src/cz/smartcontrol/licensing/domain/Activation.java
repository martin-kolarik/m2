/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.domain;

import cz.smartcontrol.licensing.domain.model.VersionedDomainObject;
import java.io.Serializable;
import java.util.Date;
import javax.persistence.CascadeType;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.FetchType;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;
import javax.persistence.Table;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.persistence.Version;

/**
 *
 * @author Martin
 */
@Entity
@Table(name="app_activation")
public class Activation implements VersionedDomainObject {
    
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "activation_id")
    private Long activationId;
    
    @ManyToOne(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="licence")
    private Licence licence;
    
    @Column(name="starts", nullable=true)
    @Temporal(TemporalType.TIMESTAMP)
    private Date starts;
    
    @Column(name="expires", nullable=true)
    @Temporal(TemporalType.TIMESTAMP)
    private Date expires;
    
    @Column(name="reg", length=64, nullable=false)
    private String reg;
    
    @Column(name="var", length=64, nullable=false)
    private String van;
    
    @Column(name="mhash", length=32, nullable=false)
    private String mhash;
    
    @Column(name="created", nullable=false)
    @Temporal(TemporalType.TIMESTAMP)
    private Date created;
    
    @Column(name="version", nullable=false)
    @Version
    private Long version;
    
    public Serializable getPrimaryKey() {
        return getActivationId();
    }

    public Long getActivationId() {
        return activationId;
    }

    public void setActivationId( Long activationId ) {
        this.activationId = activationId;
    }

    public Licence getLicence() {
        return licence;
    }

    public void setLicence( Licence licence ) {
        this.licence = licence;
    }

    public Date getStarts() {
        return starts;
    }

    public void setStarts( Date starts ) {
        this.starts = starts;
    }

    public Date getExpires() {
        return expires;
    }

    public void setExpires( Date expires ) {
        this.expires = expires;
    }

    public String getReg() {
        return reg;
    }

    public void setReg( String reg ) {
        this.reg = reg;
    }

    public String getVan() {
        return van;
    }

    public void setVan( String van ) {
        this.van = van;
    }

    public String getMhash() {
        return mhash;
    }

    public void setMhash( String mhash ) {
        this.mhash = mhash;
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
