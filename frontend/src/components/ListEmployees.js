import React, { useState, useEffect } from "react";
import axios from "axios";

const API_URL = "/api";

function ListEmployees({ refreshFlag }) {
  const [employees, setEmployees] = useState([]);

  useEffect(() => {
    const fetchEmployees = async () => {
      try {
        const res = await axios.get(`${API_URL}/employees`);
        setEmployees(Array.isArray(res.data) ? res.data : []);
      } catch (err) {
        console.error("Error fetching employees:", err);
        setEmployees([]);
      }
    };
    fetchEmployees();
  }, [refreshFlag]);

  return (
    <table className="table table-striped table-hover">
      <thead className="table-dark">
        <tr>
          <th>Emp No</th>
          <th>Name</th>
          <th>Salary</th>
        </tr>
      </thead>
      <tbody>
        {employees.map(emp => (
          <tr key={emp.empno}>
            <td>{emp.empno}</td>
            <td>{emp.empname}</td>
            <td>{emp.salary}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export default ListEmployees;

