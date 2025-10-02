import React, { useState, useEffect } from "react";
import axios from "axios";

// Use the same backend environment variable
const API_URL = "/api";

function ListEmployees({ refreshFlag }) {
  const [employees, setEmployees] = useState([]);

  useEffect(() => {
    const fetchEmployees = async () => {
      try {
        const res = await axios.get(`${API_URL}/employees`);
        // Ensure the data is always an array
        setEmployees(Array.isArray(res.data) ? res.data : []);
      } catch (err) {
        console.error("Error fetching employees:", err);
        setEmployees([]);
      }
    };
    fetchEmployees();
  }, [refreshFlag]);

  return (
    <div>
      <h4>List of Employees</h4>
      <table className="table">
        <thead>
          <tr>
            <th>Emp No</th>
            <th>Name</th>
            <th>Salary</th>
          </tr>
        </thead>
        <tbody>
          {employees.map((emp) => (
            <tr key={emp.empno}>
              <td>{emp.empno}</td>
              <td>{emp.empname}</td>
              <td>{emp.salary}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default ListEmployees;

