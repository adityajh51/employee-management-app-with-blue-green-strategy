package com.example.demo.controller;

import com.example.demo.entity.Employee;
import com.example.demo.service.EmployeeService;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/api/employees")
public class EmployeeController {
    private final EmployeeService service;

    public EmployeeController(EmployeeService service) { this.service = service; }

    @PostMapping("/add")
    public Employee addEmployee(@RequestBody Employee employee) { return service.save(employee); }

    @GetMapping
    public List<Employee> getEmployees() { return service.findAll(); }
}
