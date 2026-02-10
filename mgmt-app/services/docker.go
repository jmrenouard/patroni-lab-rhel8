package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"strings"

	"github.com/moby/moby/api/types/container"
	"github.com/moby/moby/client"
)

// DockerService gère les interactions avec le démon Docker local.
type DockerService struct {
	cli *client.Client
}

// NewDockerService initialise un nouveau client Docker.
func NewDockerService() (*DockerService, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, fmt.Errorf("erreur lors de la création du client Docker: %v", err)
	}
	return &DockerService{cli: cli}, nil
}

// ListContainers retourne la liste des containers liés au projet patroni.
func (s *DockerService) ListContainers(ctx context.Context) ([]container.Summary, error) {
	result, err := s.cli.ContainerList(ctx, client.ContainerListOptions{All: true})
	if err != nil {
		return nil, fmt.Errorf("erreur lors du listage des containers: %v", err)
	}
	return result.Items, nil
}

// StartContainer démarre un container spécifique par son nom ou ID.
func (s *DockerService) StartContainer(ctx context.Context, containerID string) error {
	_, err := s.cli.ContainerStart(ctx, containerID, client.ContainerStartOptions{})
	if err != nil {
		return fmt.Errorf("erreur lors du démarrage du container %s: %v", containerID, err)
	}
	return nil
}

// StopContainer arrête un container spécifique.
func (s *DockerService) StopContainer(ctx context.Context, containerID string) error {
	_, err := s.cli.ContainerStop(ctx, containerID, client.ContainerStopOptions{})
	if err != nil {
		return fmt.Errorf("erreur lors de l'arrêt du container %s: %v", containerID, err)
	}
	return nil
}

// RestartContainer redémarre un container spécifique.
func (s *DockerService) RestartContainer(ctx context.Context, containerID string) error {
	_, err := s.cli.ContainerRestart(ctx, containerID, client.ContainerRestartOptions{})
	if err != nil {
		return fmt.Errorf("erreur lors du redémarrage du container %s: %v", containerID, err)
	}
	return nil
}

// BatchControl effectue une action sur un groupe de containers (filtre par thème ou 'all').
func (s *DockerService) BatchControl(ctx context.Context, theme string, command string) error {
	containers, err := s.ListContainers(ctx)
	if err != nil {
		return err
	}

	for _, c := range containers {
		name := ""
		if len(c.Names) > 0 {
			name = c.Names[0]
		}

		match := false
		if theme == "all" {
			match = true
		} else if theme != "" {
			// Vérifie si le nom du container contient le "thème" (ex: etcd, node, haproxy)
			// On normalise en cherchant le thème comme sous-chaîne.
			match = (fmt.Sprintf("%v", name) != "" && (theme == "node" && (name == "/node1" || name == "/node2" || name == "/node3"))) ||
				(theme == "etcd" && (name == "/etcd1" || name == "/etcd2" || name == "/etcd3")) ||
				(theme == "haproxy" && name == "/haproxy") ||
				(theme == "pgbouncer" && name == "/pgbouncer")
		}

		if match {
			var errOp error
			switch command {
			case "start":
				errOp = s.StartContainer(ctx, c.ID)
			case "stop":
				errOp = s.StopContainer(ctx, c.ID)
			case "restart":
				errOp = s.RestartContainer(ctx, c.ID)
			}
			if errOp != nil {
				log.Printf("Erreur Batch (%s) sur %s: %v", command, name, errOp)
				// On continue malgré l'erreur sur un container
			}
		}
	}
	return nil
}

func (s *DockerService) findContainerID(ctx context.Context, containerName string) (string, error) {
	containers, err := s.ListContainers(ctx)
	if err != nil {
		return "", err
	}

	for _, c := range containers {
		for _, name := range c.Names {
			if strings.TrimPrefix(name, "/") == containerName {
				return c.ID, nil
			}
		}
	}
	return "", fmt.Errorf("container %s non trouvé", containerName)
}

// ExecCommand exécute une commande dans un container et retourne sa sortie.
func (s *DockerService) ExecCommand(ctx context.Context, containerName string, cmd []string) (string, error) {
	containerID, err := s.findContainerID(ctx, containerName)
	if err != nil {
		return "", err
	}

	config := client.ExecCreateOptions{
		Cmd:          cmd,
		AttachStdout: true,
		AttachStderr: true,
	}

	execID, err := s.cli.ExecCreate(ctx, containerID, config)
	if err != nil {
		return "", err
	}

	resp, err := s.cli.ExecAttach(ctx, execID.ID, client.ExecAttachOptions{})
	if err != nil {
		return "", err
	}
	defer resp.Close()

	output, err := io.ReadAll(resp.Reader)
	if err != nil {
		return "", err
	}

	return string(output), nil
}

// GetContainerStats récupère les statistiques d'utilisation du container (Usage Unique).
func (s *DockerService) GetContainerStats(ctx context.Context, containerName string) (map[string]interface{}, error) {
	containerID, err := s.findContainerID(ctx, containerName)
	if err != nil {
		return nil, err
	}

	stats, err := s.cli.ContainerStats(ctx, containerID, client.ContainerStatsOptions{Stream: false})
	if err != nil {
		return nil, err
	}
	defer stats.Body.Close()

	var res map[string]interface{}
	if err := json.NewDecoder(stats.Body).Decode(&res); err != nil {
		return nil, err
	}

	return res, nil
}

// GetContainerLogs récupère les logs du container.
func (s *DockerService) GetContainerLogs(ctx context.Context, containerName string, tail string) (string, error) {
	containerID, err := s.findContainerID(ctx, containerName)
	if err != nil {
		return "", err
	}

	options := client.ContainerLogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Tail:       tail,
	}

	logs, err := s.cli.ContainerLogs(ctx, containerID, options)
	if err != nil {
		return "", err
	}
	defer logs.Close()

	content, err := io.ReadAll(logs)
	if err != nil {
		return "", err
	}

	// Nettoyage rapide des headers multiplexés si présents
	return string(bytes.ReplaceAll(content, []byte{1, 0, 0, 0}, []byte{})), nil
}
