package com.example.demo.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "employee")
public class Employee {
    @Id
    private String empno;
    private String empname;
    private String salary;

    // Getters and Setters
    public String getEmpno() { return empno; }
    public void setEmpno(String empno) { this.empno = empno; }

    public String getEmpname() { return empname; }
    public void setEmpname(String empname) { this.empname = empname; }

    public String getSalary() { return salary; }
    public void setSalary(String salary) { this.salary = salary; }
}
